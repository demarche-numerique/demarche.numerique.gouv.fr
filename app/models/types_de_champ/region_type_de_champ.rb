# frozen_string_literal: true

class TypesDeChamp::RegionTypeDeChamp < TypesDeChamp::TextTypeDeChamp
  include AddressableColumnConcern

  def columns(procedure_id:, displayable: true, prefix: nil)
    addressable_columns(procedure_id:, displayable:, prefix:, only: [:region_code])
      .concat(legacy_columns(procedure_id:, prefix:))
  end

  def filter_to_human(filter_value)
    APIGeoService.region_name(filter_value).presence || filter_value
  end

  def filled_champ_value(champ)
    champ.name
  end

  def filled_champ_value_for_export(champ, path = :value)
    case path
    when :value
      filled_champ_value(champ)
    when :code
      champ.code
    end
  end

  def filled_champ_value_for_tag(champ, path = :value)
    case path
    when :value
      filled_champ_value(champ)
    when :code
      champ.code
    end
  end

  private

  # ChampColumn par défaut conservé pour rester résolvable par les ProcedurePresentation /
  # exports / colonnes graphql persistées avant la bascule sur AddressableColumnConcern.
  def legacy_columns(procedure_id:, prefix:)
    [
      Columns::ChampColumn.new(
        procedure_id:,
        stable_id:,
        tdc_type: type_champ,
        label: libelle_with_prefix(prefix),
        type: :enum,
        displayable: false,
        filterable: false,
        options_for_select:,
        mandatory: mandatory?
      ),
    ]
  end

  def paths
    paths = super
    paths.push({
      libelle: "#{libelle} (Code)",
      description: "#{description} (Code)",
      path: :code,

    })
    paths
  end
end
