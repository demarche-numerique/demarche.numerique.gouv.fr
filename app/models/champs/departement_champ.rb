# frozen_string_literal: true

class Champs::DepartementChamp < Champs::TextChamp
  store_accessor :value_json,  :code_region

  validate :value_in_departement_names, if: -> { !value.nil? && validate_champ_value? }
  validate :external_id_in_departement_codes, if: -> { !external_id.nil? && validate_champ_value? }
  before_save :store_code_region

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
    if [2, 3].include?(code&.size)
      self.external_id = code
      super(APIGeoService.departement_name(code))
    elsif code.blank?
      self.external_id = nil
      super(nil)
    else
      self.external_id = APIGeoService.departement_code(code)
      super(code)
    end
  end

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
  end
end
