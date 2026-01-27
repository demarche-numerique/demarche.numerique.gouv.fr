# frozen_string_literal: true

module Mutations
  class DossierArchiver < Mutations::BaseMutation
    description "Archiver le dossier."

    argument :dossier_id, ID, "Dossier ID", required: true, loads: Types::DossierType
    argument :instructeur_id, ID, "Instructeur qui prend la décision sur le dossier.", required: true, loads: Types::ProfileType

    field :dossier, Types::DossierType, null: true
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(dossier:, instructeur:)
      dossier.archiver!(instructeur)

      { dossier: }
    end

    def authorized?(dossier:, instructeur:)
      if !dossier.termine?
        return false, { errors: [I18n.t('activerecord.errors.models.dossier.cannot_archive')] }
      end

      dossier_authorized_for?(dossier, instructeur)
    end
  end
end
