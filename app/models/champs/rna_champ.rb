# frozen_string_literal: true

class Champs::RNAChamp < Champ
  include RNAChampAssociationFetchableConcern

  RNA_REGEXP = /\AW[0-9A-Z]{9}\z/

  validates :value, allow_blank: true, format: {
    with: RNA_REGEXP, message: :invalid_rna,
  }, if: :validate_champ_value?

  validate :ensure_association_found, if: :validate_champ_value?

  delegate :id, to: :procedure, prefix: true

  def title
    data&.dig("association_titre")
  end

  def update_external_data!(value:, data:)
    value_json = data.blank? ? nil : extract_value_json(data:)
    data = (data.presence)
    update_columns(data:, value_json:, value:, fetch_external_data_exceptions: [])
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

  private

  def ensure_association_found
    if value&.match(RNA_REGEXP) && data.blank?
      errors.add(:value, :not_found)
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
