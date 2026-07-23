# frozen_string_literal: true

module Webhooks
  class DeliveryJob < ApplicationJob
    queue_as :default

    BATCH_SIZE = 100
    # keeps a run well under CLAIM_TTL
    MAX_BATCHES_PER_RUN = 20
    TIMEOUT = 15
    MAX_RESPONSE_SIZE = 64.kilobytes
    SAFETY_LAG = 5.seconds
    CLAIM_TTL = 10.minutes

    def perform(webhook_id)
      Sentry.set_tags(webhook: webhook_id)
      claimed_at = claim(webhook_id)
      return if claimed_at.nil?

      more = false
      begin
        # read under the claim: an earlier read may hold a cursor or a
        # subscription another run or a modification has since changed
        webhook = Webhook.find_by(id: webhook_id)
        return if webhook.nil?

        Sentry.set_tags(procedure: webhook.procedure_id)
        more = deliver_pending_events(webhook, claimed_at)
      ensure
        release(webhook_id, claimed_at)
      end

      Webhooks::DeliveryJob.perform_later(webhook_id) if more
    end

    private

    # One run at a time per webhook, none while it backs off. The claim
    # expires so a killed worker cannot block the webhook.
    def claim(webhook_id)
      claimed_at = Time.current
      claimed = Webhook
        .deliverable
        .where(id: webhook_id)
        .where("delivery_claimed_at IS NULL OR delivery_claimed_at < ?", CLAIM_TTL.ago)
        .where("retry_at IS NULL OR retry_at <= ?", claimed_at)
        .update_all(delivery_claimed_at: claimed_at) == 1
      claimed_at if claimed
    end

    def release(webhook_id, claimed_at)
      Webhook.where(id: webhook_id, delivery_claimed_at: claimed_at).update_all(delivery_claimed_at: nil)
    end

    # true when events remain for a follow-up job
    def deliver_pending_events(webhook, claimed_at)
      MAX_BATCHES_PER_RUN.times do
        ceiling = ceiling(webhook)
        events = pending_events(webhook, ceiling)

        if events.empty?
          skip_other_events(webhook, claimed_at, ceiling)
          return false
        end

        error = deliver(webhook, events)

        if error.nil?
          return false if !advance_cursor(webhook, claimed_at, events.last.id)
        else
          register_failure(webhook, claimed_at, error)
          return false
        end
      end

      true
    end

    # Only advances while this run still holds the claim: a subscription
    # change clears it (Webhook#invalidate_delivery_claim).
    def advance_cursor(webhook, claimed_at, cursor)
      advanced = Webhook
        .deliverable
        .where(id: webhook.id, delivery_claimed_at: claimed_at)
        .update_all(
          cursor:,
          consecutive_failures: 0,
          last_attempt_at: Time.current,
          last_success_at: Time.current,
          retry_at: nil,
          last_error: nil,
          updated_at: Time.current
        ) == 1
      webhook.reload if advanced
      advanced
    end

    # The highest id the run may deliver or move the cursor to, nil when
    # there is none. It stays below the oldest recent event, which may sit
    # next to a lower id not yet committed. Ids are not monotone in
    # created_at, hence an id horizon rather than a filter on created_at.
    # One query: an event committed between two would be passed unseen.
    def ceiling(webhook)
      events = WebhookEvent.where(procedure_id: webhook.procedure_id)
      horizon = events.where("created_at > ?", SAFETY_LAG.ago).select("MIN(id)")

      events
        .where("id > ?", webhook.cursor)
        # no recent event: a NULL horizon, nothing to stay below
        .where("(id >= (?)) IS NOT TRUE", horizon)
        .maximum(:id)
    end

    def pending_events(webhook, ceiling)
      return [] if ceiling.nil?

      webhook.pending_events.where(id: ..ceiling).order(:id).limit(BATCH_SIZE).to_a
    end

    # Moves the cursor over other types' events so pending queries skip them.
    def skip_other_events(webhook, claimed_at, ceiling)
      return if ceiling.nil?

      Webhook
        .deliverable
        .where(id: webhook.id, delivery_claimed_at: claimed_at)
        .update_all(cursor: ceiling, updated_at: Time.current)
    end

    # nil when delivered, the error otherwise
    def deliver(webhook, events)
      url = PublicAddressResolver.request_url(webhook.url)
      addresses = PublicAddressResolver.addresses(url)
      # one message: telling an unresolvable host from a private one would
      # reveal internal names
      if addresses.empty? || addresses.any? { PublicAddressResolver.private_address?(it) }
        return "L'URL du webhook n'est pas autorisée"
      end

      body = payload(webhook, events)
      message_id = "msg_#{webhook.id}_#{events.first.id}_#{events.last.id}"
      timestamp = Time.current.to_i
      response = Typhoeus.post(
        url,
        body:,
        headers: {
          'Content-Type' => 'application/json',
          'webhook-id' => message_id,
          'webhook-timestamp' => timestamp.to_s,
          'webhook-signature' => signature(webhook, "#{message_id}.#{timestamp}.#{body}"),
        },
        timeout: TIMEOUT,
        maxfilesize: MAX_RESPONSE_SIZE,
        # a redirect would bypass the pinned addresses
        followlocation: false,
        resolve: PublicAddressResolver.resolve_pin(url, addresses)
      )

      if !(200..299).cover?(response.code)
        "HTTP #{response.code} (#{response.return_message})"
      end
    end

    def payload(webhook, events)
      {
        webhook_id: webhook.to_typed_id,
        demarche_number: webhook.procedure_id,
        events: events.map do |event|
          {
            sequence: event.id,
            type: event.event_type,
            dossier_number: event.dossier_id,
            timestamp: event.created_at.iso8601,
          }
        end,
      }.to_json
    end

    def signature(webhook, content)
      webhook.signing_secrets.map do |secret|
        key = Base64.strict_decode64(secret.delete_prefix(Webhook::SECRET_PREFIX))
        "v1,#{Base64.strict_encode64(OpenSSL::HMAC.digest('SHA256', key, content))}"
      end.join(' ')
    end

    # Re-read under lock: a concurrent webhookActiver may have reset the
    # counters since the run started.
    def register_failure(webhook, claimed_at, error)
      webhook = Webhook.transaction do
        Webhook.deliverable.lock.find_by(id: webhook.id, delivery_claimed_at: claimed_at)&.tap do |locked|
          locked.consecutive_failures += 1
          locked.last_attempt_at = Time.current
          locked.last_error = error

          if locked.consecutive_failures >= Webhook::MAX_ATTEMPTS
            locked.enabled = false
            locked.auto_disabled_at = Time.current
          else
            locked.retry_at = locked.retry_delay.from_now
          end

          locked.save!
        end
      end
      return if webhook.nil?

      if webhook.enabled?
        Webhooks::DeliveryJob.set(wait_until: webhook.retry_at).perform_later(webhook.id)
      else
        notify_auto_disabled(webhook)
      end
    end

    def notify_auto_disabled(webhook)
      webhook.procedure.administrateurs.each do |administrateur|
        AdministrateurMailer.notify_webhook_auto_disabled(administrateur, webhook).deliver_later
      end
    end
  end
end
