# frozen_string_literal: true

module AddressableColumnConcern
  extend ActiveSupport::Concern

  def addressable_columns(procedure:, displayable: true, prefix: nil)
    [
      ["Code postal (5 chiffres)", '$.postal_code', :text, []],
      ["Commune", '$.city_name', :text, []],
      ["Département", '$.department_code', :enum, APIGeoService.departement_options],
      ["Région", '$.region_name', :enum, APIGeoService.region_options, '$.region_code'],
    ].map do |(label, jsonpath, type, options_for_select, filter_jsonpath)|
      Columns::JSONPathColumn.new(
        procedure_id: procedure.id,
        stable_id:,
        tdc_type: type_champ,
        label: "#{libelle_with_prefix(prefix)} – #{label}",
        jsonpath:,
        filter_jsonpath:,
        displayable:,
        options_for_select:,
        type:,
        mandatory: mandatory?
      )
    end
  end
end
