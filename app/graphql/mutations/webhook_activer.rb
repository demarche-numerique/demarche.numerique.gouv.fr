# frozen_string_literal: true

module Mutations
  class WebhookActiver < Mutations::WebhookBaseMutation
    description "Activer un webhook (après une désactivation manuelle ou automatique). Les évènements en attente sont livrés dans l’ordre."

    argument :webhook, ID, "Identifiant du webhook.", required: true, loads: Types::WebhookType

    field :webhook, Types::WebhookType, null: true
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(webhook:)
      webhook.enabled? ? webhook.clear_backoff! : webhook.reactivate!
      Webhooks::DeliveryJob.perform_later(webhook.id)

      { webhook: }
    end
  end
end
