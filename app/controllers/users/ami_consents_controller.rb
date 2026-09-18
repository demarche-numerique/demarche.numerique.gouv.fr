# frozen_string_literal: true

module Users
  # Consentement de l'usager au suivi de ses démarches dans l'application
  # mobile AMI. Il vaut pour toutes ses démarches, mais se donne depuis un
  # dossier, dont l'événement est envoyé dans la foulée de l'acceptation.
  class AmiConsentsController < UserController
    before_action :set_dossier
    before_action :ensure_consent_available

    def show
      @status = Ami::ConsentStatus.call(fc_hash)
    end

    # Mieux vaut avouer l'échec que confirmer un suivi qui n'existe pas : le
    # bouton reste alors affiché, avec un message, pour permettre un nouvel essai.
    def create
      @status = Ami::GrantConsent.call(dossier: @dossier, fc_hash:)
      @focus = @status == :granted

      render :show
    end

    private

    # current_user.dossiers exclut les dossiers où l'usager est seulement
    # invité : le consentement porte sur son identité France Connect, pas sur
    # celle du propriétaire du dossier.
    def set_dossier = @dossier = current_user.dossiers.find(params[:id])

    # On répond toujours par le turbo-frame, même vide : une réponse sans frame
    # afficherait « Content missing » à la place de l'encart.
    def ensure_consent_available
      return if Ami::Client.new.configured? &&
        @dossier.procedure.feature_enabled?(:ami_notifications) &&
        fc_hash.present?

      @status = :unavailable
      render :show
    end

    def fc_hash = @fc_hash ||= Ami::RecipientFcHash.call(current_user)
  end
end
