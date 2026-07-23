# frozen_string_literal: true

module Mutations
  class WebhookRenouvelerSecret < Mutations::WebhookBaseMutation
    description "Renouveler le secret d’un webhook. Pendant la période de transition, chaque livraison est signée avec le nouveau et l’ancien secret : déployez le nouveau secret avant l’expiration de l’ancien."

    argument :webhook, ID, "Identifiant du webhook.", required: true, loads: Types::WebhookType
    argument :delai_expiration_ancien_secret, Int,
      "Durée en heures pendant laquelle l’ancien secret signe encore les livraisons (#{Webhook::SECRET_OVERLAP_DEFAULT.in_hours.to_i} par défaut, #{Webhook::SECRET_OVERLAP_MAX.in_hours.to_i} au plus). 0 l’invalide immédiatement, par exemple après une fuite.",
      required: false,
      default_value: Webhook::SECRET_OVERLAP_DEFAULT.in_hours.to_i,
      replace_null_with_default: true,
      validates: { numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: Webhook::SECRET_OVERLAP_MAX.in_hours.to_i } }

    field :webhook, Types::WebhookType, null: true
    field :secret, String, null: true, description: "Nouveau secret servant à vérifier la signature des livraisons."
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(webhook:, delai_expiration_ancien_secret:)
      webhook.renew_secret!(overlap: delai_expiration_ancien_secret.hours)
      { webhook:, secret: webhook.secret }
    end
  end
end
