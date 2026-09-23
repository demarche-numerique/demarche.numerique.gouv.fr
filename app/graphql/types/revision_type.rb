# frozen_string_literal: true

module Types
  class RevisionType < Types::BaseObject
    global_id_field :id
    field :date_creation, GraphQL::Types::ISO8601DateTime, "Date de la création.", null: false, method: :created_at
    field :date_publication, GraphQL::Types::ISO8601DateTime, "Date de la publication.", null: true, method: :published_at

    field :champ_descriptors, [Types::ChampDescriptorType], null: false
    field :annotation_descriptors, [Types::ChampDescriptorType], null: false

    def champ_descriptors
      object.public_root_type_de_champs
    end

    def annotation_descriptors
      if context.authorized_demarche?(object.procedure)
        object.private_root_type_de_champs
      else
        []
      end
    end
  end
end
