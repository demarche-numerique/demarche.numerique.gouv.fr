# frozen_string_literal: true

module Types
  class RevisionType < Types::BaseObject
    global_id_field :id
    field :date_creation, GraphQL::Types::ISO8601DateTime, "Date de la création.", null: false, method: :created_at
    field :date_publication, GraphQL::Types::ISO8601DateTime, "Date de la publication.", null: true, method: :published_at

    field :champ_descriptors, [Types::ChampDescriptorType], null: false, method: :public_revision_type_de_champs
    field :annotation_descriptors, [Types::ChampDescriptorType], null: false
    field :ineligibilite, Types::IneligibiliteType, "Règle d’inéligibilité de la révision (`null` si elle n’est pas activée).", null: true

    def ineligibilite
      if object.ineligibilite_enabled? && object.ineligibilite_rules.present?
        object
      end
    end

    def annotation_descriptors
      if context.authorized_demarche?(object.procedure)
        object.private_revision_type_de_champs
      else
        []
      end
    end
  end
end
