# frozen_string_literal: true

class Champs::RNAChamp < ChampData
  RNA_REGEXP = /\AW[0-9A-Z]{9}\z/

  validates :external_id, allow_blank: true, format: {
    with: RNA_REGEXP, message: :invalid_rna,
  }, if: :should_validate_in_current_context?

  delegate :id, to: :procedure, prefix: true

  def title
    data&.dig("association_titre")
  end

  def identifier
    title.present? ? "#{value} (#{title})" : value
  end

  def status_message?
    true
  end

  def search_terms
    etablissement.present? ? etablissement.search_terms : [value]
  end

  def full_address
    address = data&.dig("adresse")
    return if address.blank?
    "#{address["numero_voie"]} #{address["type_voie"]} #{address["libelle_voie"]} #{address["code_postal"]} #{address["commune"]}"
  end

  def rna_address
    address = data&.dig("adresse")
    return if address.blank?
    {
      label: full_address,
      type: "housenumber",
      street_address: address["libelle_voie"] ? [address["numero_voie"], address["type_voie"], address["libelle_voie"]].compact.join(' ') : nil,
      street_number: address["numero_voie"],
      street_name: [address["type_voie"], address["libelle_voie"]].compact.join(' '),
      postal_code: address["code_postal"],
      city_name: address["commune"],
      city_code: address["code_insee"],
    }.with_indifferent_access
  end

  def has_async_external_data?
    true
  end

  private

  def ready_for_external_call?
    external_id&.match?(RNA_REGEXP)
  end

  def fetch_external_data
    case APIEntreprise::RNAAdapter.new(external_id, procedure_id).to_params
    in Success(data) if data.present?
      Success(data:, value_json: extract_value_json(data:), value: external_id)
    in Success # not found returns an empty hash
      Failure(retryable: false, error: StandardError.new('NotFound'), code: 404)
    in Failure(type:, code:, retryable:, **)
      Failure(retryable:, error: StandardError.new("API Entreprise: #{type}"), code:)
    end
  end

  def extract_value_json(data:)
    h = APIGeoService.parse_rna_address(data['adresse'])
    h.merge(
      title: data['association_titre'],
      association_rna: data['association_rna'],
      association_objet: data['association_objet'],
      association_date_creation: data['association_date_creation'],
      association_date_declaration: data['association_date_declaration'],
      association_date_publication: data['association_date_publication']
    )
  end
end
