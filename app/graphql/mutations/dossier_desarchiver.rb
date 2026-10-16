# frozen_string_literal: true

module Mutations
  class DossierDesarchiver < Mutations::BaseMutation
    description "Désarchiver le dossier."

    argument :dossier_id, ID, "Dossier ID", required: true, loads: Types::DossierType
    argument :instructeur_id, ID, "Instructeur qui prend la décision sur le dossier.", required: true, loads: Types::ProfileType

    field :dossier, Types::DossierType, null: true
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(dossier:, instructeur:)
      dossier.desarchiver!(instructeur)

      { dossier: }
    end

    def authorized?(dossier:, instructeur:)
      if !dossier.archived?
        return false, { errors: ["Un dossier non archivé ne peut pas être désarchivé"] }
      end

      dossier_authorized_for?(dossier, instructeur)
    end
  end
end
