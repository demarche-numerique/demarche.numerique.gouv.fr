# frozen_string_literal: true

module Mutations
  # The mutations editing the champs of the draft revision of a démarche. They
  # hold the GraphQL contract only: DraftEditorService does the edit and words
  # the refusals.
  class DemarcheBrouillonMutation < Mutations::BaseMutation
    class InvalidId < StandardError; end

    argument :demarche, Types::DemarcheDescriptorType::FindDemarcheInput, "La démarche", required: true

    field :champ_descriptor, Types::ChampDescriptorType, "Le champ ajouté ou modifié, tel que le décrit le brouillon de la démarche.", null: true
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(demarche:, **args)
      demarche_number = demarche.number.presence || ApplicationRecord.id_from_typed_id(demarche.id)
      procedure = Procedure.find_by(id: demarche_number)

      if procedure.blank? || !context.authorized_demarche?(procedure)
        return { errors: ["La démarche \"#{demarche_number}\" n'existe pas ou vous n'avez pas le droit de la modifier."] }
      end

      result = edit(DraftEditorService.new(procedure), **args)

      if result.success?
        { champ_descriptor: procedure.draft_revision.type_de_champ(result.stable_id) }
      else
        { errors: result.errors }
      end
    rescue InvalidId => e
      { errors: [e.message] }
    end

    private

    # The id a ChampDescriptor exposes is the stable id of the champ, typed.
    def stable_id_from(id)
      return nil if id.nil?

      type, stable_id = GraphQL::Schema::UniqueWithinType.decode(id)
      raise InvalidId if type != 'Champ' || stable_id.blank?

      stable_id
    rescue StandardError # whatever the decoding makes of an id that is not one
      raise InvalidId, "L'identifiant de champ \"#{id}\" est invalide."
    end
  end
end
