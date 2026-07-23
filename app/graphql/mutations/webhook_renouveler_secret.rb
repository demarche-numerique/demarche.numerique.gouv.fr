# frozen_string_literal: true

module Mutations
  class WebhookRenouvelerSecret < Mutations::WebhookBaseMutation
    description "Renouveler le secret d'un webhook. L’ancien secret est immédiatement invalidé."

    argument :webhook, ID, "Identifiant du webhook.", required: true, loads: Types::WebhookType

    field :webhook, Types::WebhookType, null: true
    field :secret, String, null: true, description: "Nouveau secret servant à vérifier la signature des livraisons."
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(webhook:)
      return { errors: [FEATURE_DISABLED_ERROR] } if feature_disabled?(webhook.procedure)

      webhook.regenerate_secret
      { webhook:, secret: webhook.secret }
    end
  end
end
