# frozen_string_literal: true

module Users
  # Consentement de l'usager au suivi de ses démarches dans l'application
  # mobile AMI. La ressource porte sur l'usager lui-même, et non sur un
  # dossier : le consentement vaut pour toutes ses démarches.
  class AmiConsentsController < UserController
    include Dry::Monads[:result]

    before_action :ensure_consent_available

    def show
      @status = Ami::ConsentStatus.call(current_user)
    end

    def create
      case Ami::GrantConsent.call(current_user)
      in Success(_)
        @status = :granted
        @focus = true
      in Failure(_)
        @status = :not_granted
        @error = true
      end

      render :show
    end

    private

    # On répond toujours par le turbo-frame, même vide : une réponse sans frame
    # afficherait « Content missing » à la place de l'encart.
    def ensure_consent_available
      return if Ami::Client.new.configured? && Ami::RecipientFcHash.call(current_user).present?

      @status = :unavailable
      render :show
    end
  end
end
