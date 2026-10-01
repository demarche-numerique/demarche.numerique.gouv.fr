# frozen_string_literal: true

class Types::WebhookType < Types::BaseObject
  description "Un webhook configuré sur une démarche. Les évènements sont livrés par lots ordonnés, signés selon la spécification Standard Webhooks (https://www.standardwebhooks.com) : en-têtes `webhook-id`, `webhook-timestamp` et `webhook-signature`, vérifiables avec ses bibliothèques officielles. Le numéro de séquence des évènements est strictement croissant (avec des trous) : il permet de dédupliquer et d’ordonner les livraisons."

  global_id_field :id

  field :url, String, null: false, description: "URL de destination des livraisons."
  field :label, String, null: true, description: "Libellé du webhook."
  field :event_types, [Types::WebhookEventTypeEnum], null: false, description: "Types d’évènements auxquels le webhook est abonné."
  field :enabled, Boolean, null: false, description: "Le webhook est-il activé ?"
  field :auto_disabled_at, GraphQL::Types::ISO8601DateTime, null: true, description: "Date de désactivation automatique, après des échecs répétés de livraison ou une réponse 410 Gone. Utilisez la mutation `webhookActiver` pour le réactiver."
  field :last_error, String, null: true, description: "Dernière erreur de livraison rencontrée."
  field :last_success_at, GraphQL::Types::ISO8601DateTime, null: true, description: "Date de la dernière livraison réussie."
  field :previous_secret_expires_at, GraphQL::Types::ISO8601DateTime, null: true, description: "Après un renouvellement du secret, date jusqu’à laquelle l’ancien secret signe encore les livraisons."
  field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: "Date de création du webhook."

  def previous_secret_expires_at
    object.previous_secret_expires_at if object.previous_secret_valid?
  end

  def self.authorized?(object, context)
    context.authorized_demarche?(object.procedure)
  end
end
