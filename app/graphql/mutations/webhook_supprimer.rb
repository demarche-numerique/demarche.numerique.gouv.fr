# frozen_string_literal: true

module Mutations
  class WebhookSupprimer < Mutations::WebhookBaseMutation
    description "Supprimer un webhook."

    argument :webhook, ID, "Identifiant du webhook.", required: true, loads: Types::WebhookType

    field :id, ID, null: true, description: "Identifiant du webhook supprimé."
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(webhook:)
      webhook.destroy!
      { id: webhook.to_typed_id }
    end
  end
end
