# frozen_string_literal: true

module Ami
  # L'usager accepte de suivre ses démarches dans l'application mobile : on
  # enregistre son consentement auprès d'AMI, puis on lui envoie l'événement du
  # dossier depuis lequel il a accepté.
  #
  # Il n'existe volontairement pas de service de révocation : elle se fait
  # depuis les préférences de l'application mobile.
  #
  # Retourne un statut du même vocabulaire que ConsentStatus, prêt pour
  # AmiConsentStateComponent : :granted ou :error.
  class GrantConsent
    include Dry::Monads[:result]

    def self.call(dossier:, fc_hash: nil) = new(dossier, fc_hash).call

    def initialize(dossier, fc_hash = nil)
      @dossier = dossier
      @fc_hash = fc_hash
    end

    def call
      case Client.new.grant_consent(fc_hash)
      in Success(_)
        # skip_consent_check: le consentement vient d'être accordé, le job n'a
        # pas à le relire — AMI pourrait ne pas l'avoir encore propagé.
        CreateNotificationService.call(dossier:, skip_consent_check: true)
        :granted
      in Failure(API::Client::Error => error)
        # Sans consentement enregistré, l'événement n'a pas à partir : son
        # contenu ne doit pas parvenir à AMI.
        Rails.logger.warn("Ami::GrantConsent failed: #{error.type} code: #{error.code}")
        :error
      end
    end

    private

    attr_reader :dossier

    # L'appelant a déjà le hash sous la main la plupart du temps : le recalculer
    # coûterait une requête de plus.
    def fc_hash = @fc_hash ||= RecipientFcHash.call(dossier.user)
  end
end
