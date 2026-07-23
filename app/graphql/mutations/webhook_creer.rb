# frozen_string_literal: true

module Mutations
  class WebhookCreer < Mutations::WebhookBaseMutation
    description "Créer un webhook sur une démarche. Le secret n’est renvoyé que par cette mutation et par `webhookRenouvelerSecret` : conservez-le."

    argument :demarche, Types::DemarcheDescriptorType::FindDemarcheInput, "La démarche", required: true
    argument :url, String, "URL de destination des livraisons.", required: true
    argument :event_types, [Types::WebhookEventTypeEnum], "Types d’évènements auxquels abonner le webhook.", required: true
    argument :label, String, "Libellé du webhook.", required: false

    field :webhook, Types::WebhookType, null: true
    field :secret, String, null: true, description: "Secret servant à vérifier la signature des livraisons."
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(demarche:, url:, event_types:, label: nil)
      procedure = find_authorized_demarche(demarche)

      if procedure.nil?
        return { errors: ["La démarche \"#{demarche_number(demarche)}\" n'existe pas ou vous n'avez pas le droit de la modifier."] }
      end

      if feature_disabled?(procedure)
        return { errors: [FEATURE_DISABLED_ERROR] }
      end

      webhook = procedure.webhooks.build(url:, event_types:, label:)

      if webhook.save
        { webhook:, secret: webhook.secret }
      else
        { errors: webhook.errors.full_messages }
      end
    end
  end
end
