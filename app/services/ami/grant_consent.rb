# frozen_string_literal: true

module Ami
  # L'usager accepte de suivre ses démarches dans l'application mobile : on
  # enregistre son consentement auprès d'AMI, puis on lui envoie l'événement du
  # dossier depuis lequel il a accepté.
  #
  # Il n'existe volontairement pas de service de révocation : elle se fait
  # depuis les préférences de l'application mobile.
  #
  # Retourne le Result de l'écriture du consentement, dont l'appelant a besoin
  # pour savoir quoi afficher.
  class GrantConsent
    def self.call(dossier:) = new(dossier).call

    def initialize(dossier)
      @dossier = dossier
    end

    def call
      result = Client.new.grant_consent(RecipientFcHash.call(dossier.user))
      # Sans consentement enregistré, l'événement n'a pas à partir : son contenu
      # ne doit pas parvenir à AMI.
      return result if result.failure?

      # grant_consent: le consentement vient d'être accordé, le job n'a pas à le
      # revérifier — AMI pourrait ne pas l'avoir encore propagé.
      CreateNotificationService.call(dossier:, grant_consent: true)

      result
    end

    private

    attr_reader :dossier
  end
end
