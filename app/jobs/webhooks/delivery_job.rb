# frozen_string_literal: true

module Webhooks
  class DeliveryJob < ApplicationJob
    queue_as :default

    BATCH_SIZE = 100
    # Bounds a run to end well before CLAIM_TTL (each batch costs at most one
    # TIMEOUT-bounded HTTP call plus bookkeeping); a longer backlog is handed
    # to a fresh job.
    MAX_BATCHES_PER_RUN = 20
    TIMEOUT = 10
    SAFETY_LAG = 5.seconds
    CLAIM_TTL = 10.minutes

    def perform(webhook_id)
      webhook = Webhook.deliverable.find_by(id: webhook_id)
      return if webhook.nil?
      # Jobs enqueued for new events land here while a previous failure is
      # backing off: honour the backoff — the scheduled retry (or the cron
      # sweeper) picks the events up later.
      return if webhook.in_backoff?

      claimed_at = claim(webhook)
      return if claimed_at.nil?

      more = false
      begin
        more = deliver_pending_events(webhook, claimed_at)
      ensure
        release(webhook, claimed_at)
      end

      # After the release, so the follow-up job can claim immediately.
      Webhooks::DeliveryJob.perform_later(webhook.id) if more
    end

    private

    # At most one in-flight delivery per webhook. The claim is TTL-based so a
    # killed worker never wedges the webhook (the cron sweeper re-enqueues),
    # and runs are bounded to end well before the TTL; release only clears the
    # claim this run wrote, so a takeover after an anomalous stall past the
    # TTL is not clobbered.
    def claim(webhook)
      claimed_at = Time.current
      claimed = Webhook
        .where(id: webhook.id)
        .where("delivery_claimed_at IS NULL OR delivery_claimed_at < ?", CLAIM_TTL.ago)
        .update_all(delivery_claimed_at: claimed_at) == 1
      claimed_at if claimed
    end

    def release(webhook, claimed_at)
      Webhook.where(id: webhook.id, delivery_claimed_at: claimed_at).update_all(delivery_claimed_at: nil)
    end

    # Returns true when a backlog remains for a follow-up job.
    def deliver_pending_events(webhook, claimed_at)
      MAX_BATCHES_PER_RUN.times do
        events = pending_events(webhook)
        return false if events.empty?

        delivered = deliver(webhook, events)

        # Re-checked after the HTTP call, before any bookkeeping: losing the
        # claim mid-run (reactivate! and subscription changes clear it to
        # invalidate this run) or losing deliverability (disabled, or the
        # démarche discarded) must stop the run — a successor may already be
        # delivering, and writing the cursor or failure counters here would
        # fight it. The batch just sent may be re-sent later (deliveries are
        # at-least-once).
        return false if !still_claimed?(webhook, claimed_at)

        if delivered
          return false if !advance_cursor(webhook, claimed_at, events.last.id)
        else
          register_failure(webhook)
          return false
        end
      end

      true
    end

    # Compare-and-swap on the claim: the cursor only advances when this run
    # still holds it at write time. A subscription change clears the claim in
    # the same transaction (see Webhook#invalidate_delivery_claim), so a run
    # filtering on outdated event_types can never move the cursor past an
    # event only the new subscription selects.
    def advance_cursor(webhook, claimed_at, cursor)
      advanced = Webhook
        .where(id: webhook.id, delivery_claimed_at: claimed_at)
        .update_all(
          cursor:,
          consecutive_failures: 0,
          last_attempt_at: Time.current,
          last_success_at: Time.current,
          last_error: nil,
          updated_at: Time.current
        ) == 1
      webhook.reload if advanced
      advanced
    end

    def still_claimed?(webhook, claimed_at)
      Webhook.deliverable.exists?(id: webhook.id, delivery_claimed_at: claimed_at)
    end

    # The safety lag keeps us from reading around an event whose id is lower
    # than the latest visible one but whose transaction has not committed yet
    # (delivering past it would skip it forever). The cut is an id horizon,
    # not a per-row timestamp filter: ids are not monotone in created_at (the
    # timestamp is taken before the INSERT, so a concurrent emitter can land a
    # lower id with a newer timestamp), and filtering rows individually would
    # let the cursor jump past such a fresh event for good.
    def pending_events(webhook)
      horizon = WebhookEvent
        .where(procedure_id: webhook.procedure_id)
        .where("created_at > ?", SAFETY_LAG.ago)
        .minimum(:id)

      scope = webhook.pending_events
      scope = scope.where(id: ...horizon) if horizon
      scope.order(:id).limit(BATCH_SIZE).to_a
    end

    # No blanket rescue here: an unexpected exception is an internal bug, not
    # an endpoint failure — let it propagate (job retry + Sentry) instead of
    # counting towards auto-disable. Network-level failures never raise:
    # Typhoeus reports them as a response code outside 2xx.
    def deliver(webhook, events)
      addresses = NoPrivateIPURLValidator.vetted_public_addresses(webhook.url)
      if addresses.nil?
        webhook.last_error = "L'URL du webhook pointe vers une adresse IP privée"
        return false
      end

      body = payload(webhook, events)
      response = Typhoeus.post(
        webhook.url,
        body:,
        headers: {
          'Content-Type' => 'application/json',
          'X-Webhook-Signature-256' => signature(webhook, body),
        },
        timeout: TIMEOUT,
        # A redirect would re-resolve outside the pin: keep redirects disabled.
        followlocation: false,
        resolve: NoPrivateIPURLValidator.resolve_pin(webhook.url, addresses)
      )

      if (200..299).cover?(response.code)
        true
      else
        webhook.last_error = "HTTP #{response.code} (#{response.return_message})"
        false
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

    def signature(webhook, body)
      "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', webhook.secret, body)}"
    end

    def register_failure(webhook)
      webhook.consecutive_failures += 1
      webhook.last_attempt_at = Time.current

      if webhook.consecutive_failures >= Webhook::MAX_ATTEMPTS
        webhook.enabled = false
        webhook.auto_disabled_at = Time.current
        webhook.save!
        notify_auto_disabled(webhook)
      else
        webhook.save!
        Webhooks::DeliveryJob.set(wait: webhook.backoff_delay).perform_later(webhook.id)
      end
    end

    def notify_auto_disabled(webhook)
      webhook.procedure.administrateurs.each do |administrateur|
        AdministrateurMailer.notify_webhook_auto_disabled(administrateur, webhook).deliver_later
      end
    end
  end
end
