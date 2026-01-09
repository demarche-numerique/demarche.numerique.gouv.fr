# frozen_string_literal: true

module Mutations
  class DossierEnvoyerMessage < Mutations::BaseMutation
    description "Envoyer un message à l’usager du dossier."

    argument :dossier_id, ID, required: true, loads: Types::DossierType
    argument :instructeur_id, ID, required: true, loads: Types::ProfileType
    argument :body, String, required: true
    argument :attachment, ID, required: false
    argument :correction, Types::CorrectionType::CorrectionReason, 'Préciser qu’il s’agit d’une demande de correction. Le dossier repasssera en construction.', required: false

    field :message, Types::MessageType, null: true
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(dossier:, instructeur:, body:, attachment: nil, correction: nil)
      message = CommentaireService.create(instructeur, dossier, body: body, piece_jointe: attachment)

      if message.errors.empty?
        if correction
          dossier.flag_as_pending_correction!(message, correction)
        end

        { message: }
      else
        { errors: message.errors.full_messages }
      end
    end

    def authorized_before_load?(attachment: nil, **args)
      if attachment.present?
        validate_blob(attachment)
      else
        true
      end
    end

    def authorized?(dossier:, instructeur:, **args)
      dossier_authorized_for?(dossier, instructeur)
    end
  end
end
