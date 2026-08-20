# frozen_string_literal: true

module Ami
  # TODO: nom public de l'application, à figer avec l'équipe AMI
  APP_NAME = "AMI"

  # TODO: URL provisoire, à remplacer par l'écran de téléchargement (universal
  # link) que doit nous fournir l'équipe AMI
  APP_URL = "https://ami.numerique.gouv.fr"

  # AMI n'expose pas encore d'écriture du consentement. En attendant, c'est le
  # premier événement envoyé qui vaut consentement ; il suffira d'activer cette
  # variable le jour où l'endpoint existera.
  def self.grant_consent_endpoint_available?
    ENV.enabled?("AMI_GRANT_CONSENT_ENDPOINT_AVAILABLE")
  end
end
