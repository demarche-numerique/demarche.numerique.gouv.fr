# frozen_string_literal: true

module Mutations
  class DossierEnvoyerMessage < Mutations::BaseMutation
    include DossierHelper

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

      if correction
        # flag_as_pending_correction! assigns the correction to the commentaire
        # in-memory, then saves it, so Commentaire#notify (after_create) enqueues
        # notify_pending_correction rather than notify_new_answer.
        dossier.flag_as_pending_correction!(message, correction)
      else
        CommentaireService.persist!(message)
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

    def authorized?(dossier:, instructeur:, correction: nil, **args)
      if correction.present? && !dossier.may_flag_as_pending_correction?
        return false, { errors: [correction_error_message(dossier)] }
      end

      dossier_authorized_for?(dossier, instructeur)
    end

    private

    def correction_error_message(dossier)
      if dossier.pending_corrections.exists?
        "Une demande de correction est déjà en attente sur ce dossier"
      else
        "Le dossier ne peut pas faire l’objet d’une demande de correction car il est #{dossier_display_state(dossier, lower: true)}"
      end
    end
  end
end
