# frozen_string_literal: true

module Ami
  # L'usager accepte de suivre ses démarches dans l'application mobile.
  #
  # Tant qu'AMI n'expose pas d'écriture du consentement, c'est le premier
  # événement reçu qui fait foi : on envoie donc l'événement du dossier depuis
  # lequel l'usager accepte, en court-circuitant la vérification qui, sinon,
  # interdirait à jamais ce premier envoi.
  #
  # Il n'existe volontairement pas de service de révocation : elle se fait
  # depuis les préférences de l'application mobile.
  class GrantConsent
    def self.call(dossier:) = new(dossier).call

    def initialize(dossier)
      @dossier = dossier
    end

    def call
      if Ami.grant_consent_endpoint_available?
        Client.new.grant_consent(RecipientFcHash.call(dossier.user))
      else
        CreateNotificationService.call(dossier:, grant_consent: true)
      end
    end

    private

    attr_reader :dossier
  end
end
