# frozen_string_literal: true

class Champs::RNFChamp < ChampData
  RNF_REGEXP = /\A[A-Za-z0-9-]{12,20}\z/i.freeze
  TOKEN_ALERT_EVERY = 1.hour

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

  # What the usager cannot fix must not block them: our token refused or the
  # API down both degrade, only an unknown RNF fails.
  def fetch_external_data
    case RNFService.new.(rnf_id:)
    in Success(data)
      Success(data:, value_json: extract_value_json(data:))
    in Failure(code: 401..403 => code, error:)
      alert_token_refused(code)
      Failure(degraded: true, error:, code:)
    in Failure(retryable: true, error:, code:)
      Failure(degraded: true, error:, code:)
    in Failure => failure
      failure
    end
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

  # Every RNF champ of the instance hits the same wall: one alert per hour is enough.
  def alert_token_refused(code)
    return if !Rails.cache.write('rnf:token_refused', true, expires_in: TOKEN_ALERT_EVERY, unless_exist: true)

    Sentry.capture_message("RNF token is refused", level: :error, extra: { code: })
  end

  def extract_value_json(data:)
    h = APIGeoService.parse_rnf_address(data[:address])
    h.merge(title: data[:title])
  end
end
