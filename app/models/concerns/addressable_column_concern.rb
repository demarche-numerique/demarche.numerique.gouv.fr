# frozen_string_literal: true

module AddressableColumnConcern
  extend ActiveSupport::Concern

  DEFAULT_ADDRESSABLE_COLUMNS = [:postal_code, :city_name, :department_code, :region_code].freeze

  def addressable_columns(procedure_id:, displayable: true, prefix: nil, deprecated_columns: false, only: DEFAULT_ADDRESSABLE_COLUMNS)
    column_specs = [
      [:postal_code, "Code postal (5 chiffres)", '$.postal_code', :text, [], displayable, true],
      [:city_name, "Commune", '$.city_name', :text, [], displayable, true],
      [:department_code, "Département", '$.department_code', :enum, APIGeoService.departement_options, displayable, true],
      [:region_code, "Région", '$.region_code', :enum, APIGeoService.region_options, displayable, true],
      [:city_code, "Code INSEE", '$.city_code', :text, [], displayable, true],
    ]

    column_specs = column_specs.filter { only.include?(_1.first) }

    columns = column_specs.map do |(_key, label, jsonpath, type, options_for_select, column_displayable, column_filterable)|
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

    # legacy: kept resolvable for procedure_presentations / export_templates saved before the jsonpath fix
    columns << region_name_legacy_column(procedure_id:, prefix:) if deprecated_columns
    columns
  end

  private

  def region_name_legacy_column(procedure_id:, prefix:)
    Columns::JSONPathColumn.new(
      procedure_id:,
      stable_id:,
      tdc_type: type_champ,
      label: "#{libelle_with_prefix(prefix)} – Région",
      jsonpath: '$.region_name',
      displayable: false,
      filterable: false,
      deprecated: true,
      options_for_select: APIGeoService.region_options,
      type: :enum,
      mandatory: mandatory?
    )
  end
end
