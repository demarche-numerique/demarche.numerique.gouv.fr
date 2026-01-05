# frozen_string_literal: true

module Mutations
  class DossierAnnulerDemandeCorrection < Mutations::BaseMutation
    description "Annuler une demande de correction sans supprimer le message."

    argument :message_id, ID, required: true, loads: Types::MessageType
    argument :instructeur_id, ID, required: true, loads: Types::ProfileType

    field :message, Types::MessageType, null: true
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(message:, **args)
      message.cancel_correction!

      { message: }
    end

    def authorized?(message:, instructeur:, **args)
      if !can_cancel_correction?(message)
        return false, { errors: ["La demande de correction ne peut pas être annulée"] }
      end
      dossier_authorized_for?(message.dossier, instructeur)
    end

    private

    def can_cancel_correction?(message)
      message.dossier_correction&.pending? && !message.discarded?
    end
  end
end
