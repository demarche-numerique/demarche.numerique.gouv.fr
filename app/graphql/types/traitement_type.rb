# frozen_string_literal: true

module Types
  class TraitementType < Types::BaseObject
    class TraitementEvent < Types::BaseEnum
      Traitement::EVENT.each do |event, name|
        value(event, name, value: event)
      end
    end

    global_id_field :id
    field :state, Types::DossierType::DossierState, null: false, deprecation_reason: 'Utilisez le champ `event` à la place.'
    field :event, TraitementEvent, null: false
    field :date_traitement, GraphQL::Types::ISO8601DateTime, null: false, method: :processed_at
    field :email_agent_traitant, String, null: true, method: :instructeur_email
    field :motivation, String, null: true
    field :revision, Types::RevisionType, null: true
    field :changed_columns, [Types::ColumnType], "Liste des changements par colonne", null: false

    def revision
      dataloader.with(Sources::Association, revision: :procedure).load(object)
    end
  end
end
