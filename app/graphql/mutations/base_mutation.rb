# frozen_string_literal: true

module Mutations
  class BaseMutation < GraphQL::Schema::RelayClassicMutation
    include DemarcheAuthorizationConcern

    private

    delegate :current_administrateur, to: :context

    def ready?(**args)
      if context.write_access?
        authorized_before_load?(**args)
      else
        return false, { errors: ['Le jeton utilisé est configuré seulement en lecture'] }
      end
    end

    def authorized_before_load?(**args)
      true
    end

    def partition_instructeurs_by(instructeurs)
      instructeurs
        .partition { _1.id.present? }
        .then do |by_id, by_email|
          [
            by_id.map { Instructeur.id_from_typed_id(_1.id) },
            by_email.map { EmailSanitizableConcern::EmailSanitizer.sanitize(_1.email) },
          ]
        end
    end

    def partition_administrators_by_profile_input(administrators)
      administrators
        .partition { _1.id.present? }
        .then do |by_id, by_email|
        [
          by_id.map { Administrateur.id_from_typed_id(_1.id) },
          by_email.map { EmailSanitizableConcern::EmailSanitizer.sanitize(_1.email) },
        ]
      end
    end

    def validate_blob(blob_id)
      begin
        blob = ActiveStorage::Blob.find_signed(blob_id)
        raise ActiveSupport::MessageVerifier::InvalidSignature if blob.nil?

        # open downloads the file and checks its hash
        blob.open { |f| }
        true
      rescue ActiveStorage::FileNotFoundError
        return false, { errors: ['Le fichier n’a pas été correctement téléversé sur le serveur de stockage'] }
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        return false, { errors: ['L’identifiant du fichier téléversé est invalide'] }
      rescue ActiveStorage::IntegrityError
        return false, { errors: ['Le hash du fichier téléversé est invalide'] }
      end
    end

    def dossier_authorized_for?(dossier, instructeur)
      if instructeur.is_a?(Instructeur) && instructeur.dossiers.exists?(id: dossier.id)
        true
      else
        return false, { errors: ['L’instructeur n’a pas les droits d’accès à ce dossier'] }
      end
    end
  end
end
