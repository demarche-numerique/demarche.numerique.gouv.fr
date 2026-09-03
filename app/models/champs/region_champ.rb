# frozen_string_literal: true

class Champs::RegionChamp < Champs::TextChamp
  store_accessor :value_json, :region_code
  before_save :store_region_code

  NAMES = APIGeoService.regions.pluck(:name).freeze
  CODES = APIGeoService.regions.pluck(:code).freeze

  validates :value,
            inclusion: { in: NAMES, message: :not_in_region_names },
            allow_nil: true,
            if: :should_validate_in_current_context?
  validates :external_id,
            inclusion: { in: CODES, message: :not_in_region_codes },
            allow_nil: true,
            if: :should_validate_in_current_context?

  def selected
    code
  end

  def name
    value
  end

  def code
    external_id || APIGeoService.region_code(value)
  end

  def value=(code)
    resolution = APIGeoService.resolve_region(code)
    self.external_id = resolution&.code
    super(resolution&.name)
  end

  def condition_value = code

  private

  def store_region_code
    self.region_code = code
  end
end
