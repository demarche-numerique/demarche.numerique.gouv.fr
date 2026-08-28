# frozen_string_literal: true

# Encart proposant à l'usager de suivre ses démarches dans l'application
# mobile AMI, et de la télécharger. La partie qui dépend du consentement est
# chargée à part, cf. Dossiers::AmiConsentStateComponent.
class Dossiers::AmiFollowComponent < ApplicationComponent
  MODAL_ID = "ami-info-modal"
  MODAL_TITLE_ID = "#{MODAL_ID}-title"

  attr_reader :dossier

  def initialize(dossier:)
    @dossier = dossier
  end

  # Le partiel de la page de dépôt sert aussi d'aperçu à l'administrateur,
  # sans dossier. Le consentement demande une identité France Connect.
  def render?
    dossier.present? &&
      dossier.procedure.feature_enabled?(:ami_notifications) &&
      Ami::Client.new.configured? &&
      Ami::RecipientFcHash.call(dossier.user).present?
  end

  # Point de surcharge de la preview, qui n'a pas de dossier à router.
  def consent_path = ami_consent_dossier_path(dossier)
end
