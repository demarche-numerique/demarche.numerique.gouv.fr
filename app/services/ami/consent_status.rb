# frozen_string_literal: true

module Ami
  # L'usager a-t-il consenti au suivi de ses démarches dans l'application mobile ?
  #
  # Pas de cache pour l'instant : interroger AMI à chaque affichage garantit
  # qu'une révocation faite depuis l'application est prise en compte aussitôt.
  class ConsentStatus
    include Dry::Monads[:result]

    def self.call(user) = new(user).call

    def initialize(user)
      @user = user
    end

    def call
      return :unknown if fc_hash.blank?
      return :unknown if !client.configured?

      case client.consent(fc_hash)
      in Success(_)
        :granted
      in Failure(API::Client::Error => error) if error.code == 404
        :not_granted
      in Failure(API::Client::Error => error)
        Sentry.capture_message("Ami::ConsentStatus failed: #{error.type} code: #{error.code}")
        :unknown
      end
    end

    private

    attr_reader :user

    def fc_hash = @fc_hash ||= RecipientFcHash.call(user)
    def client = @client ||= Client.new
  end
end
