# frozen_string_literal: true

class APIRechercheEntreprisesService
  include Dry::Monads[:result]

  def self.collectivite_territoriale?(siret:)
    response = APIRechercheEntreprisesService.new.call(siret:)

    return false if response.failure?

    response.success&.dig(:complements, :collectivite_territoriale).present?
  end

  def call(siret:)
    result = API::Client.new.(url: "#{url}?q=#{siret}")

    return result if result.failure?

    body = result.success.body

    # the api can return a Success without results (in particular for organisations whose information cannot be disclosed)
    return Failure() if body[:results].empty?

    # the api returns the matching structure in the first element if it exists
    structure = body[:results][0]

    # safety check : the api does fuzzy matching, so we need to check that the siret matches
    return Failure() if structure[:matching_etablissements].all? { _1[:siret] != siret }

    Success(structure)
  end

  private

  def url
    "#{API_RECHERCHE_ENTREPRISE_URL}/search"
  end
end
