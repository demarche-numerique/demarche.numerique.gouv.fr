# frozen_string_literal: true

module Webhooks
  class EmitEventService
    def self.call(dossier:, event_type:)
      # nil once the démarche is discarded
      procedure = dossier.procedure
      return if procedure.nil?
      # the API does not expose brouillons
      return if dossier.brouillon?
      return unless procedure.feature_enabled?(:webhooks_api)

      webhooks = procedure.webhooks.subscribed_to(event_type.to_s).to_a
      return if webhooks.empty?

      WebhookEvent.create!(procedure:, dossier_id: dossier.id, event_type:)

      webhooks.filter(&:enabled?).each(&:schedule_delivery)
    rescue StandardError => e
      Sentry.capture_exception(e, tags: { procedure: procedure&.id, dossier: dossier.id }.compact, extra: { event_type: })
    end
  end
end
