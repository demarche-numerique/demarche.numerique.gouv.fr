# frozen_string_literal: true

module Ami
  # Transmet à AMI le consentement de l'usager au suivi de ses démarches.
  #
  # Il n'existe volontairement pas de service de révocation : celle-ci doit se
  # faire depuis les préférences de l'application mobile, et nous ne devons
  # jamais envoyer d'événement de refus.
  class GrantConsent
    include Dry::Monads[:result]

    def self.call(user) = new(user).call

    def initialize(user)
      @user = user
    end

    def call
      return Failure(:no_france_connect_identity) if fc_hash.blank?
      return Failure(:not_configured) if !client.configured?

      client.grant_consent(fc_hash)
    end

    private

    attr_reader :user

    def fc_hash = @fc_hash ||= RecipientFcHash.call(user)
    def client = @client ||= Client.new
  end
end
