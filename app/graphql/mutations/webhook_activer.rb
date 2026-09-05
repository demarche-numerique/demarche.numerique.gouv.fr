# frozen_string_literal: true

module Mutations
  class WebhookActiver < Mutations::WebhookBaseMutation
    description "Activer un webhook (après une désactivation manuelle ou automatique). Les évènements en attente sont livrés dans l’ordre."

    argument :webhook, ID, "Identifiant du webhook.", required: true, loads: Types::WebhookType

    field :webhook, Types::WebhookType, null: true
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(webhook:)
      return { errors: [FEATURE_DISABLED_ERROR] } if feature_disabled?(webhook.procedure)

      # On an already-enabled webhook, reactivate! would clear the claim of a
      # delivery possibly running right now, handing its work to a concurrent
      # second job — but a pending backoff must still be lifted, or the
      # enqueued job returns immediately and the promised catch-up delivery
      # waits for the scheduled retry.
      webhook.enabled? ? webhook.clear_backoff! : webhook.reactivate!
      Webhooks::DeliveryJob.perform_later(webhook.id)

      { webhook: }
    end
  end
end
