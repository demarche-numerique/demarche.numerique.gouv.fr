# frozen_string_literal: true

module AddressableColumnConcern
  extend ActiveSupport::Concern

  def addressable_columns(displayable: true, prefix: nil, deprecated_columns: false, only: nil)
    column_specs = [
      [:postal_code, "Code postal (5 chiffres)", '$.postal_code', :text, [], displayable, true],
      [:city_name, "Commune", '$.city_name', :text, [], displayable, true],
      [:department_code, "Département", '$.department_code', :enum, APIGeoService.departement_options, displayable, true],
      [:region_code, "Région", '$.region_code', :enum, APIGeoService.region_options, displayable, true],
    ]

    column_specs = column_specs.filter { only.include?(_1.first) } if only

    # legacy: kept resolvable for procedure_presentations / export_templates saved before the jsonpath fix
    if deprecated_columns
      column_specs << [:region_name_legacy, "Région", '$.region_name', :enum, APIGeoService.region_options, false, false]
    end

    column_specs.map do |(_key, label, jsonpath, type, options_for_select, column_displayable, column_filterable)|
      Columns::JSONPathColumn.new(
        procedure_id:,
        stable_id:,
        tdc_type: type_champ,
        label: "#{libelle_with_prefix(prefix)} – #{label}",
        jsonpath:,
        displayable: column_displayable,
        filterable: column_filterable,
        options_for_select:,
        type:,
        mandatory: mandatory?
      )
    end
  end
end
