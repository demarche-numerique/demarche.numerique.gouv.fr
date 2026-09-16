# frozen_string_literal: true

class Champs::CommuneChamp < Champs::TextChamp
  store_accessor :value_json, :department_code, :postal_code, :region_code
  before_save :on_codes_change, if: :should_refresh_after_code_change?

  validates :external_id, presence: true, if: -> { value.present? && should_validate_in_current_context? }
  after_validation :instrument_external_id_error, if: -> { errors.include?(:external_id) }

  def departement_name
    APIGeoService.departement_name(department_code)
  end

  def departement_code_and_name
    if departement?
      "#{department_code} – #{departement_name}"
    end
  end

  def departement
    { code: department_code, name: departement_name }
  end

  def departement?
    department_code.present?
  end

  def code?
    code.present?
  end

  def postal_code?
    postal_code.present?
  end

  def name
    APIGeoService.safely_normalize_city_name(department_code, code, safe_to_s)
  end

  def code
    external_id
  end

  def selected
    code? ? "#{code}-#{postal_code}" : nil
  end

  def selected_items
    if code?
      [{ label: to_s, value: selected }]
    else
      []
    end
  end

  def code=(code)
    if code.blank?
      self.department_code = nil
      self.postal_code = nil
      self.external_id = nil
      self.value = nil
    elsif code.match?(/-/)
      codes = code.split('-')
      self.external_id = codes.first
      self.postal_code = codes.second
    else
      self.external_id = code
    end
  end

  def condition_value = { department_code:, region_code: }

  private

  def safe_to_s
    value.present? ? value.to_s : ''
  end

  def communes
    if postal_code?
      APIGeoService.communes_by_postal_code(postal_code)
    else
      []
    end
  end

  def on_codes_change
    return if !code?

    commune = communes.find { _1[:code] == code }

    if commune.present?
      self.department_code = commune[:department_code]
      self.region_code = commune[:region_code]
      self.value = commune[:name]
      value_json['city_name'] = commune[:name]
      value_json['city_code'] = commune[:code]
    else
      self.department_code = nil
      self.postal_code = nil
      self.external_id = nil
      self.value = nil
      value_json['city_name'] = nil
      value_json['city_code'] = nil
    end
  end

  def should_refresh_after_code_change?
    !departement? || postal_code_changed? || external_id_changed?
  end

  def instrument_external_id_error
    Sentry.capture_message(
      "Commune with value and no external id Edge case reached",
      extra: { request_id: Current.request_id }
    )
  end
end
