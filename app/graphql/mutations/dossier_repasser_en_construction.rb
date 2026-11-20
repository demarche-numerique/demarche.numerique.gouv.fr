# frozen_string_literal: true

module Mutations
  class DossierRepasserEnConstruction < Mutations::BaseMutation
    include DossierHelper

    description "Re-passer le dossier en construction."

    argument :dossier_id, ID, "Dossier ID", required: true, loads: Types::DossierType
    argument :instructeur_id, ID, "Instructeur qui prend la décision sur le dossier.", required: true, loads: Types::ProfileType
    argument :disable_notification, Boolean, "Désactiver l’envoi de l’email de notification après l’opération", required: false, default_value: false

    field :dossier, Types::DossierType, null: true
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(dossier:, instructeur:, disable_notification:)
      dossier.repasser_en_construction!(instructeur:, disable_notification:)

      { dossier: }
    end

    def authorized?(dossier:, instructeur:, **args)
      if !dossier.en_instruction?
        return false, { errors: ["Le dossier est déjà #{dossier_display_state(dossier, lower: true)}"] }
      end
      if !dossier.can_repasser_en_construction?
        return false, { errors: ["Le dossier ne peut pas repasser en construction car la démarche est en décision implicite (SVA/SVR). Utilisez la mutation `dossierEnvoyerMessage` avec l’argument `correction` pour demander une correction à l’usager."] }
      end
      dossier_authorized_for?(dossier, instructeur)
    end
  end
end
