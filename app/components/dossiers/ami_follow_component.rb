# frozen_string_literal: true

# Encart proposant à l'usager de suivre ses démarches dans l'application
# mobile AMI, et de la télécharger. La partie qui dépend du consentement est
# chargée à part, cf. Dossiers::AmiConsentStateComponent.
class Dossiers::AmiFollowComponent < ApplicationComponent
  MODAL_ID = "ami-info-modal"

  def initialize(dossier:)
    @dossier = dossier
  end

  # Le partiel de la page de dépôt sert aussi d'aperçu à l'administrateur,
  # sans dossier. Le consentement demande une identité France Connect.
  def render?
    @dossier.present? &&
      @dossier.procedure.feature_enabled?(:ami_notifications) &&
      Ami::Client.new.configured? &&
      Ami::RecipientFcHash.call(@dossier.user).present?
  end

  def app_name = Ami::APP_NAME

  def app_url = Ami::APP_URL

  def modal_id = MODAL_ID

  def title_id = "#{MODAL_ID}-title"
end
