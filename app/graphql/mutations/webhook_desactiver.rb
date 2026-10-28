# frozen_string_literal: true

module Mutations
  class WebhookDesactiver < Mutations::WebhookBaseMutation
    description "Désactiver un webhook. Les évènements de la démarche continuent d’être enregistrés et seront livrés à la réactivation."

    argument :webhook, ID, "Identifiant du webhook.", required: true, loads: Types::WebhookType

    field :webhook, Types::WebhookType, null: true
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(webhook:)
      webhook.update!(enabled: false)
      { webhook: }
    end
  end
end
