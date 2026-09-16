# frozen_string_literal: true

class Champs::DepartementChamp < Champs::TextChamp
  store_accessor :value_json, :region_code

  NAMES = APIGeoService.departements.pluck(:name).freeze
  CODES = APIGeoService.departements.pluck(:code).freeze

  validates :value,
            inclusion: { in: NAMES, message: :not_in_departement_names },
            allow_nil: true,
            if: :should_validate_in_current_context?
  validates :external_id,
            inclusion: { in: CODES, message: :not_in_departement_codes },
            allow_nil: true,
            if: :should_validate_in_current_context?
  before_save :store_codes

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

  def region_code
    APIGeoService.region_code_by_departement(code)
  end

  def value=(code)
    resolution = APIGeoService.resolve_departement(code)
    self.external_id = resolution&.code
    super(resolution&.name)
  end

  def condition_value = { value: code, region_code: }

  private

  def store_codes
    self.region_code = region_code
    value_json['department_code'] = code
  end
end
