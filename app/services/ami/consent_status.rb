# frozen_string_literal: true

module Ami
  # L'usager a-t-il consenti au suivi de ses démarches dans l'application mobile ?
  # Prend le hash France Connect, seul identifiant connu d'AMI, que ses deux
  # appelants (le job d'envoi et le contrôleur) ont déjà sous la main.
  #
  # Pas de cache : interroger AMI à chaque fois garantit qu'une révocation faite
  # depuis l'application est prise en compte aussitôt.
  class ConsentStatus
    include Dry::Monads[:result]

    def self.call(fc_hash) = new(fc_hash).call

    def initialize(fc_hash)
      @fc_hash = fc_hash
    end

    def call
      return :unavailable if fc_hash.blank?
      return :unavailable if !client.configured?

      case client.consent(fc_hash)
      in Success(_)
        :granted
      in Failure(API::Client::Error => error) if error.code == 404
        :not_granted
      in Failure(API::Client::Error => error)
        # Pas de remontée Sentry ici : l'appelant décide quoi en faire, et le
        # job lève, ce qui suffit à signaler une panne d'AMI.
        Rails.logger.warn("Ami::ConsentStatus failed: #{error.type} code: #{error.code}")
        :unknown
      end
    end

    private

    attr_reader :fc_hash

    def client = @client ||= Client.new
  end
end
