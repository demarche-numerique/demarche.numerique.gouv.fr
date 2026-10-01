# frozen_string_literal: true

module AddressableColumnConcern
  extend ActiveSupport::Concern

  DEFAULT_ADDRESSABLE_COLUMNS = [:postal_code, :city_name, :department_code, :region_code].freeze

  def addressable_columns(procedure_id:, displayable: true, prefix: nil, only: DEFAULT_ADDRESSABLE_COLUMNS)
    column_specs = [
      [:postal_code, "Code postal (5 chiffres)", '$.postal_code', :text, []],
      [:city_name, "Commune", '$.city_name', :text, []],
      [:department_code, "Département", '$.department_code', :enum, APIGeoService.departement_options],
      [:region_code, "Région", '$.region_code', :enum, APIGeoService.region_options],
      [:city_code, "Code INSEE", '$.city_code', :text, []],
    ]

    column_specs.filter { only.include?(_1.first) }.map do |(_key, label, jsonpath, type, options_for_select)|
      Columns::JSONPathColumn.new(
        procedure_id:,
        stable_id:,
        tdc_type: type_champ,
        label: "#{libelle_with_prefix(prefix)} – #{label}",
        jsonpath:,
        displayable:,
        options_for_select:,
        type:,
        mandatory: mandatory?
      )
    end
  end
end
