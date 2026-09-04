# frozen_string_literal: true

class Champs::DepartementChamp < Champs::TextChamp
  store_accessor :value_json,  :code_region

  validate :value_in_departement_names, if: -> { !value.nil? && should_validate_in_current_context? }
  validate :external_id_in_departement_codes, if: -> { !external_id.nil? && should_validate_in_current_context? }
  before_save :store_code_region

  def code_region=(v)
    super
    value_json['region_code'] = v
  end

  def selected
    code
  end

  def code
    external_id || APIGeoService.departement_code(name)
  end

  def name
    maybe_code_and_name = value&.match(/^(\w{2,3}) - (.+)/)
    if maybe_code_and_name
      maybe_code_and_name[2]
    else
      value
    end
  end

  def code_region
    APIGeoService.region_code_by_departement(code)
  end

  def value=(code)
    resolution = APIGeoService.resolve_departement(code)
    self.external_id = resolution&.code
    super(resolution&.name)
  end

  def condition_value = blank? ? nil : { value: code, region_code: code_region }

  private

  def value_in_departement_names
    return if value.in?(APIGeoService.departements.pluck(:name))

    errors.add(:value, :not_in_departement_names)
  end

  def external_id_in_departement_codes
    return if external_id.in?(APIGeoService.departements.pluck(:code))

    errors.add(:external_id, :not_in_departement_codes)
  end

  def store_code_region
    self.code_region = code_region
    value_json['department_code'] = code
  end
end
