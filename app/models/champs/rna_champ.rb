# frozen_string_literal: true

class Champs::RNAChamp < ChampData
  include APIEntrepriseChampConcern

  RNA_REGEXP = /\AW[0-9A-Z]{9}\z/

  validates :external_id, allow_blank: true, format: {
    with: RNA_REGEXP, message: :invalid_rna,
  }, if: :should_validate_in_current_context?

  delegate :id, to: :procedure, prefix: true

  def rna_id = external_id

  def external_id=(id)
    super
    self.value = rna_id
  end

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
    [value]
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
    rna_id&.match?(RNA_REGEXP)
  end

  def fetch_external_data
    return token_unusable_failure if !procedure.api_entreprise_token_usable?

    case read_association
    in Success(data:, value_json:)
      procedure.forget_api_entreprise_token_rejection!
      Success(data:, value_json:)
    in Success # not found returns an empty hash
      Failure(retryable: false, error: StandardError.new('NotFound'), code: 404)
    in Failure => failure
      api_entreprise_failure(failure)
    end
  end

  def read_association
    APIEntreprise::RNAAdapter.new(rna_id, procedure_id).to_params
      .fmap { it.present? ? { data: it, value_json: extract_value_json(data: it) } : {} }
  rescue StandardError => e
    # The API answered, we could not read it. Without this the exception escapes
    # through the state machine callback and strands the champ in fetching.
    Sentry.capture_exception(e)

    Failure(type: :unreadable_payload, code: 200, retryable: true)
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
