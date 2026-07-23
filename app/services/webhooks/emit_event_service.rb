# frozen_string_literal: true

module Webhooks
  class EmitEventService
    def self.call(dossier:, event_type:)
      # dossier.procedure is nil once the démarche has been discarded
      # (default_scope kept): the integration is over, nothing to emit.
      procedure = dossier.procedure
      return if procedure.nil?
      return unless procedure.feature_enabled?(:webhooks_api)

      webhooks = procedure.webhooks.subscribed_to(event_type.to_s).to_a
      return if webhooks.empty?

      WebhookEvent.create!(procedure:, dossier_id: dossier.id, event_type:)

      webhooks.filter(&:enabled?).each do |webhook|
        Webhooks::DeliveryJob.set(wait: Webhooks::DeliveryJob::SAFETY_LAG).perform_later(webhook.id)
      end
    rescue StandardError => e
      # Webhooks are a best-effort side channel: an emission failure must never
      # break the business operation that triggered it.
      Sentry.capture_exception(e, extra: { procedure_id: procedure&.id, dossier_id: dossier.id, event_type: })
    end
  end
end
