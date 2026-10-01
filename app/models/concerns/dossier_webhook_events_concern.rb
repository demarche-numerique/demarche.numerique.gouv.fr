# frozen_string_literal: true

module DossierWebhookEventsConcern
  extend ActiveSupport::Concern

  # Call inside the business transaction, in causal order: events are
  # recorded at commit in call order. Not from an aasm after_commit callback,
  # where a nested transition commits first.
  def emit_webhook_event(event_type)
    if !Webhook::EVENT_TYPES.include?(event_type.to_s)
      raise ArgumentError, "unknown webhook event type: #{event_type}"
    end

    ActiveRecord.after_all_transactions_commit { record_webhook_event(event_type) }
  end

  private

  def record_webhook_event(event_type)
    # nil once the démarche is discarded
    return if procedure.nil?
    # the API does not expose brouillons
    return if brouillon?

    webhooks = procedure.webhooks.subscribed_to(event_type.to_s).to_a
    return if webhooks.empty?

    WebhookEvent.create!(procedure:, dossier_id: id, event_type:)

    webhooks.filter(&:enabled?).each(&:schedule_delivery)
  rescue StandardError => e
    Sentry.capture_exception(e, tags: { procedure: procedure&.id, dossier: id }.compact, extra: { event_type: })
  end
end
