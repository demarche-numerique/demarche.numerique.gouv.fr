# frozen_string_literal: true

module Types
  class RevisionType < Types::BaseObject
    global_id_field :id
    field :date_creation, GraphQL::Types::ISO8601DateTime, "Date de la création.", null: false, method: :created_at
    field :date_publication, GraphQL::Types::ISO8601DateTime, "Date de la publication.", null: true, method: :published_at

    field :champ_descriptors, [Types::ChampDescriptorType], null: false, method: :revision_types_de_champ_public
    field :annotation_descriptors, [Types::ChampDescriptorType], null: false

    def annotation_descriptors
      if context.authorized_demarche?(object.procedure)
        object.revision_types_de_champ_private
      else
        []
      end
    end
  end
end
