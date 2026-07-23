# frozen_string_literal: true

module Mutations
  class WebhookModifier < Mutations::WebhookBaseMutation
    description "Modifier un webhook. Un type d’évènement ajouté après la création ne reçoit que les évènements émis à partir de la modification."

    argument :webhook, ID, "Identifiant du webhook.", required: true, loads: Types::WebhookType
    argument :url, String, "URL de destination des livraisons.", required: false
    argument :event_types, [Types::WebhookEventTypeEnum], "Types d’évènements auxquels abonner le webhook.", required: false
    argument :label, String, "Libellé du webhook.", required: false

    field :webhook, Types::WebhookType, null: true
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(webhook:, url: nil, event_types: nil, label: :unset)
      return { errors: [FEATURE_DISABLED_ERROR] } if feature_disabled?(webhook.procedure)

      # nil means "argument omitted"; an explicitly supplied blank value must
      # reach the model so validation rejects it instead of silently dropping it.
      attrs = {}
      attrs[:url] = url unless url.nil?
      attrs[:event_types] = event_types unless event_types.nil?
      attrs[:label] = label unless label == :unset

      return { errors: ["Aucun paramètre à modifier."] } if attrs.empty?

      if webhook.update(attrs)
        # A subscription or URL change invalidates an in-flight delivery run
        # (see Webhook#invalidate_delivery_claim): hand any pending backlog to
        # a fresh job right away instead of waiting for the sweeper.
        if webhook.event_types_previously_changed? || webhook.url_previously_changed?
          Webhooks::DeliveryJob.perform_later(webhook.id)
        end
        { webhook: }
      else
        { errors: webhook.errors.full_messages }
      end
    end
  end
end
