# frozen_string_literal: true

class APIGeoDegradedService
  # Follows API Geo structure
  CommunesResponse = Data.define(:body, :success?, :code) do
    def initialize(communes:)
      mock_response_body = communes.map do |commune|
        {
          nom: commune[:name],
          code: commune[:code],
          codesPostaux: [commune[:postal_code]],
          codeDepartement: commune[:department_code],
          codeRegion: commune[:region_code],
          population: nil,
        }
      end

      super(
        body: mock_response_body.to_json,
        success?: true,
        code: 200
      )
    end
  end

  class << self
    def fetch_communes_by_name(name, departements_data)
      communes = search_communes_by_name(name, departements_data)
      CommunesResponse.new(communes:)
    end

    def fetch_communes_by_postal_code(postal_code, departements_data)
      communes = search_communes_by_postal_code(postal_code, departements_data)
      CommunesResponse.new(communes:)
    end

    private

    def search_communes_by_name(name, departements_data)
      normalized_query = normalize_commune_name(name)
      results = []

      departements_data.each do |department_code, communes|
        next if department_code == '99' # Skip "Etranger"

        matching_communes = communes.filter do |commune|
          normalized_commune_name = normalize_commune_name(commune[:name])
          normalized_commune_name.include?(normalized_query)
        end

        results.concat(matching_communes)
        break if results.size >= 100 # perf: don't fetch all communes in many results
      end

      # Sort by relevance and postal code
      sorted_results = results.sort_by do |commune|
        normalized_commune_name = normalize_commune_name(commune[:name])
        pertinence = if normalized_commune_name == normalized_query
          0 # Correspondance exacte
        elsif normalized_commune_name.start_with?(normalized_query)
          1 # Commence par la requête
        else
          2 # Contient la requête
        end

        [pertinence, commune[:postal_code]]
      end

      sorted_results.first(100)
    end

    def search_communes_by_postal_code(postal_code, departements_data)
      results = []

      departements_data.each do |department_code, communes|
        next if department_code == '99' # Skip "Etranger"

        matching_communes = communes.filter do |commune|
          commune[:postal_code] == postal_code
        end

        if matching_communes.any?
          results.concat(matching_communes)
          break if results.size >= 20
        end
      end

      results.first(20)
    end

    def normalize_commune_name(name)
      I18n.transliterate(name).downcase.delete("\s\-_")
    end
  end
end
