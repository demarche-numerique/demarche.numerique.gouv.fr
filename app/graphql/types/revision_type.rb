# frozen_string_literal: true

module Types
  class RevisionType < Types::BaseObject
    global_id_field :id
    field :date_creation, GraphQL::Types::ISO8601DateTime, "Date de la création.", null: false, method: :created_at
    field :date_publication, GraphQL::Types::ISO8601DateTime, "Date de la publication.", null: true, method: :published_at

    field :champ_descriptors, [Types::ChampDescriptorType], null: false
    field :annotation_descriptors, [Types::ChampDescriptorType], null: false

    # Loading the types de champ of a revision is expensive, so callers hand
    # over bare revisions and the descriptors are loaded on demand, batched
    # across every revision of the response.
    def champ_descriptors
      dataloader.with(Sources::Association, :revision_type_de_champs).load(object).then do
        object.public_revision_type_de_champs
      end
    end

    def annotation_descriptors
      if context.authorized_demarche?(object.procedure)
        dataloader.with(Sources::Association, :revision_type_de_champs).load(object).then do
          object.private_revision_type_de_champs
        end
      else
        []
      end
    end
  end
end
