# frozen_string_literal: true

class APIEntreprise::Sirene
  include Dry::Monads[:result]

  def self.fetch_etablissement(siret, procedure_id) = new(siret, procedure_id).fetch_etablissement

  def initialize(siret, procedure_id)
    @siret = siret
    @procedure_id = procedure_id
  end

  def fetch_etablissement
    APIEntreprise::API.new(@procedure_id).etablissement(@siret)
      .fmap { extract_etablissement(it[:data]) }
  rescue StandardError => e
    # The API answered, we could not read it. Without this the exception escapes
    # through the state machine callback and strands the champ in fetching.
    Sentry.capture_exception(e)

    unreadable_payload
  end

  private

  def extract_etablissement(raw_data)
    params = APIEntreprise::EtablissementPayload.etablissement_params(raw_data)
      .merge(APIEntreprise::EtablissementPayload.enterprise_params(raw_data[:unite_legale]))

    Etablissement.new(params.reject { |_, value| value == APIEntreprise::Adapter::UNAVAILABLE })
  end

  # A 200 we cannot read is a fault on their side that they will fix.
  def unreadable_payload = Failure(type: :unreadable_payload, code: 200, retryable: true)
end
