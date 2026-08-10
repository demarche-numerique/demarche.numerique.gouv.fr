# frozen_string_literal: true

class TypesDeChamp::DepartementTypeDeChamp < TypesDeChamp::TextTypeDeChamp
  include AddressableColumnConcern

  def columns(displayable: true, prefix: nil)
    addressable_columns(displayable:, prefix:, only: [:department_code, :region_code])
      .concat(legacy_columns(prefix:))
  end

  def filter_to_human(filter_value)
    APIGeoService.departement_name(filter_value).presence || filter_value
  end

  def filled_champ_value(champ)
    "#{champ.code} – #{champ.name}"
  end

  def filled_champ_value_for_export(champ, path = :value)
    case path
    when :code
      champ.code
    when :value
      champ.name
    end
  end

  def filled_champ_value_for_tag(champ, path = :value)
    case path
    when :code
      champ.code
    when :value
      filled_champ_value(champ)
    end
  end

  def filled_champ_value_for_api(champ, version: 2)
    case version
    when 2
      filled_champ_value(champ).tr('–', '-')
    else
      filled_champ_value(champ)
    end
  end

  def info_columns
    Dossiers::DepartementComponent.data_labels
  end

  private

  # ChampColumn par défaut conservé pour rester résolvable par les ProcedurePresentation /
  # exports / colonnes graphql persistées avant la bascule sur AddressableColumnConcern.
  def legacy_columns(prefix:)
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
