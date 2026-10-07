# frozen_string_literal: true

class Champs::EpciChamp < Champs::TextChamp
  store_accessor :value_json, :department_code, :region_code
  before_validation :on_departement_change
  before_validation :on_epci_name_changes

  validate :department_code_in_departement_codes, if: -> { !(department_code.nil?) && should_validate_in_current_context? }
  validate :external_id_in_departement_epci_codes, if: -> { !(department_code.nil? || external_id.nil?) && should_validate_in_current_context? }
  validate :value_in_departement_epci_names, if: -> { !(department_code.nil? || external_id.nil? || value.nil?) && should_validate_in_current_context? }

  def departement_name
    APIGeoService.departement_name(department_code)
  end

  def departement
    { code: department_code, name: departement_name }
  end

  def departement?
    department_code.present?
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

  def region_code
    APIGeoService.region_code_by_departement(department_code)
  end

  def selected
    code
  end

  def value=(code_or_name)
    if code_or_name.blank? || !departement?
      self.external_id = nil
      super(nil)
    else
      self.external_id = APIGeoService.epci_code(department_code, code_or_name) || code_or_name
      super(APIGeoService.epci_name(department_code, external_id))
    end
  end

  def departement_code_and_name
    if departement?
      "#{department_code} – #{departement_name}"
    end
  end

  def condition_value = { department_code:, region_code: }

  private

  def on_departement_change
    if department_code_changed?
      self.external_id = nil
      self.value = nil
      self.region_code = region_code
    end
  end

  def department_code_in_departement_codes
    return if department_code.in?(APIGeoService.departements.pluck(:code))

    errors.add(:department_code, :not_in_departement_codes)
  end

  def external_id_in_departement_epci_codes
    return if external_id.in?(APIGeoService.epcis(department_code).pluck(:code))
    errors.add(:external_id, :not_in_departement_epci_codes)
  end

  def value_in_departement_epci_names
    return if value.in?(APIGeoService.epcis(department_code).pluck(:name))

    errors.add(:value, :not_in_departement_epci_names)
  end

  def on_epci_name_changes
    return if external_id.nil? || department_code.nil?
    return if value.in?(APIGeoService.epcis(department_code).pluck(:name))

    if external_id.in?(APIGeoService.epcis(department_code).pluck(:code))
      self.value = (external_id)
    end
  end
end
