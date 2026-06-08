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
      message = CommentaireService.build(instructeur, dossier, body: body, piece_jointe: attachment)

      return { errors: message.errors.full_messages } if message.invalid?

      if correction && dossier.may_flag_as_pending_correction?
        # flag_as_pending_correction! assigns the correction to the commentaire
        # in-memory, then saves it, so Commentaire#notify (after_create) enqueues
        # notify_pending_correction rather than notify_new_answer.
        dossier.flag_as_pending_correction!(message, correction)
      else
        message.save!
      end

      { message: }
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
