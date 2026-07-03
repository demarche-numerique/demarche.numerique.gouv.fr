# frozen_string_literal: true

class Champs::RNFChamp < Champ
  RNF_REGEXP = /\A[A-Za-z0-9-]{12,20}\z/i.freeze

  store_accessor :data, :title, :email, :phone, :createdAt, :updatedAt, :dissolvedAt, :address

  validates :value, allow_blank: true, format: {
    with: RNF_REGEXP, message: :invalid_rnf,
  }, if: :should_validate_in_current_context?
  def rnf_id
    external_id&.gsub(/[[:space:]]/, '')
  end

  def value
    rnf_id
  end

  def fetch_external_data
    RNFService.new.(rnf_id:).fmap { |data| { data:, value_json: extract_value_json(data:) } }
  end

  def has_async_external_data?
    true
  end

  def ready_for_external_call?
    rnf_id&.match?(RNF_REGEXP)
  end

  def code_departement
    address.present? && address['departmentCode']
  end

  def departement?
    code_departement.present?
  end

  def departement
    if departement?
      { code: code_departement, name: departement_name }
    end
  end

  def departement_name
    APIGeoService.departement_name(code_departement)
  end

  def departement_code_and_name
    if departement?
      "#{code_departement} – #{departement_name}"
    end
  end

  def commune_name
    if departement?
      "#{APIGeoService.commune_name(code_departement, address['cityCode'])} (#{address['postalCode']})"
    end
  end

  def commune
    if departement?
      city_code = address['cityCode']
      city_name = address['cityName']
      postal_code = address['postalCode']

      commune_name = APIGeoService.commune_name(code_departement, city_code)
      commune_code = APIGeoService.commune_code(code_departement, city_name)

      if commune_name.present?
        {
          code: city_code,
          name: commune_name,
        }
      elsif commune_code.present?
        {
          code: commune_code,
          name: city_name,
        }
      else
        {
          code: city_code,
          name: city_name,
        }
      end.merge(postal_code:)
    end
  end

  def rnf_address
    if departement?
      {
        label: address["label"],
        type: address["type"],
        street_address: address["streetAddress"],
        street_number: address["streetNumber"],
        street_name: address["streetName"],
        postal_code: address["postalCode"],
        city_name: address["cityName"],
        city_code: address["cityCode"],
        department_name: address["departmentName"],
        department_code: address["departmentCode"],
        region_name: address["regionName"],
        region_code: address["regionCode"],
      }.with_indifferent_access
    end
  end

  def full_address
    if address.present?
      address['label']
    end
  end

  private

  def extract_value_json(data:)
    h = APIGeoService.parse_rnf_address(data[:address])
    h.merge(title: data[:title])
  end
end
