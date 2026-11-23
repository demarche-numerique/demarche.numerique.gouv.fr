# frozen_string_literal: true

module Mutations
  class DossierPasserEnInstruction < Mutations::BaseMutation
    include DossierHelper

    description "Passer le dossier en instruction."

    argument :dossier_id, ID, "Dossier ID", required: true, loads: Types::DossierType
    argument :instructeur_id, ID, "Instructeur qui prend la décision sur le dossier.", required: true, loads: Types::ProfileType
    argument :disable_notification, Boolean, "Désactiver l’envoi de l’email de notification après l’opération", required: false, default_value: false

    field :dossier, Types::DossierType, null: true
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(dossier:, instructeur:, disable_notification:)
      dossier.passer_en_instruction!(instructeur:, disable_notification:)

      { dossier: }
    end

    def authorized?(dossier:, instructeur:, **args)
      if !dossier.en_construction?
        return false, { errors: ["Le dossier est déjà #{dossier_display_state(dossier, lower: true)}"] }
      end
      if dossier.blocked_with_pending_correction?
        return false, { errors: ["Le dossier est en attente de correction"] }
      end
      dossier_authorized_for?(dossier, instructeur)
    end
  end
end
