# frozen_string_literal: true

class Champs::CommuneChamp < Champs::TextChamp
  store_accessor :value_json, :code_departement, :code_postal, :code_region
  before_save :on_codes_change, if: :should_refresh_after_code_change?

  validates :external_id, presence: true, if: -> { value.present? && validate_champ_value? }
  after_validation :instrument_external_id_error, if: -> { errors.include?(:external_id) }

  def departement_name
    APIGeoService.departement_name(code_departement)
  end

  def departement_code_and_name
    if departement?
      "#{code_departement} – #{departement_name}"
    end
  end

  def departement
    { code: code_departement, name: departement_name }
  end

  def departement?
    code_departement.present?
  end

  def code?
    code.present?
  end

  def code_postal?
    code_postal.present?
  end

  alias postal_code code_postal

  def name
    APIGeoService.safely_normalize_city_name(code_departement, code, safe_to_s)
  end

  def code
    external_id
  end

  def selected
    code? ? "#{code}-#{code_postal}" : nil
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
      self.code_departement = nil
      self.code_postal = nil
      self.external_id = nil
      self.value = nil
    elsif code.match?(/-/)
      codes = code.split('-')
      self.external_id = codes.first
      self.code_postal = codes.second
    else
      self.external_id = code
    end
  end

  private

  def safe_to_s
    value.present? ? value.to_s : ''
  end

  def communes
    if code_postal?
      APIGeoService.communes_by_postal_code(code_postal)
    else
      []
    end
  end

  def on_codes_change
    return if !code?

    commune = communes.find { _1[:code] == code }

    if commune.present?
      self.code_departement = commune[:departement_code]
      self.code_region = commune[:region_code]
      self.value = commune[:name]
    else
      self.code_departement = nil
      self.code_postal = nil
      self.external_id = nil
      self.value = nil
    end
  end

  def should_refresh_after_code_change?
    !departement? || code_postal_changed? || external_id_changed?
  end

  def instrument_external_id_error
    Sentry.capture_message(
      "Commune with value and no external id Edge case reached",
      extra: { request_id: Current.request_id }
    )
  end
end
