# frozen_string_literal: true

module Mutations
  class DossierSupprimerMessage < Mutations::BaseMutation
    description "Supprimer un message."

    argument :message_id, ID, required: true, loads: Types::MessageType
    argument :instructeur_id, ID, required: true, loads: Types::ProfileType
    argument :cancel_correction,
      GraphQL::Types::Boolean,
      required: false,
      default_value: true,
      description: "Annule automatiquement la demande de correction avant de supprimer le message.",
      deprecation_reason: "Utilisez la mutation `dossierAnnulerDemandeCorrection` avant de supprimer un message avec correction. Ce paramètre sera supprimé dans une future version."

    field :message, Types::MessageType, null: true
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(message:, instructeur:, cancel_correction:, **args)
      if cancel_correction && message.dossier_correction&.pending?
        message.cancel_correction!(instructeur)
      end

      message.soft_delete!

      { message: }
    end

    def authorized?(message:, instructeur:, cancel_correction:, **args)
      if !message.soft_deletable?(instructeur, cancel_correction:)
        return false, { errors: ["Le message ne peut pas être supprimé"] }
      end
      dossier_authorized_for?(message.dossier, instructeur)
    end
  end
end
