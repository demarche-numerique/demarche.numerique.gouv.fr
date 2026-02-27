# frozen_string_literal: true

class Champs::EpciChamp < Champs::TextChamp
  store_accessor :value_json, :code_departement, :code_region
  before_validation :on_departement_change
  before_validation :on_epci_name_changes

  validate :code_departement_in_departement_codes, if: -> { !(code_departement.nil?) && validate_champ_value? }
  validate :external_id_in_departement_epci_codes, if: -> { !(code_departement.nil? || external_id.nil?) && validate_champ_value? }
  validate :value_in_departement_epci_names, if: -> { !(code_departement.nil? || external_id.nil? || value.nil?) && validate_champ_value? }

  def departement_name
    APIGeoService.departement_name(code_departement)
  end

  def departement
    { code: code_departement, name: departement_name }
  end

  def departement?
    code_departement.present?
  end

  def html_label?
    false
  end

  def legend_label?
    true
  end

  def code?
    code.present?
  end

  def name
    value
  end

  def code
    external_id
  end

  def code_region
    APIGeoService.region_code_by_departement(code_departement)
  end

  def selected
    code
  end

  def value=(code)
    if code.blank? || !departement?
      self.external_id = nil
      super(nil)
    else
      self.external_id = code
      super(APIGeoService.epci_name(code_departement, code))
    end
  end

  def departement_code_and_name
    if departement?
      "#{code_departement} – #{departement_name}"
    end
  end

  private

  def on_departement_change
    if code_departement_changed?
      self.external_id = nil
      self.value = nil
      self.code_region = code_region
    end
  end

  def code_departement_in_departement_codes
    return if code_departement.in?(APIGeoService.departements.pluck(:code))

    errors.add(:code_departement, :not_in_departement_codes)
  end

  def external_id_in_departement_epci_codes
    return if external_id.in?(APIGeoService.epcis(code_departement).pluck(:code))
    errors.add(:external_id, :not_in_departement_epci_codes)
  end

  def value_in_departement_epci_names
    return if value.in?(APIGeoService.epcis(code_departement).pluck(:name))

    errors.add(:value, :not_in_departement_epci_names)
  end

  def on_epci_name_changes
    return if external_id.nil? || code_departement.nil?
    return if value.in?(APIGeoService.epcis(code_departement).pluck(:name))

    if external_id.in?(APIGeoService.epcis(code_departement).pluck(:code))
      self.value = (external_id)
    end
  end
end
