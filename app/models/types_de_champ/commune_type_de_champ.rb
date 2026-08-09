# frozen_string_literal: true

class TypesDeChamp::CommuneTypeDeChamp < TypesDeChamp::TypeDeChampBase
  include AddressableColumnConcern

  def filled_champ_value_for_export(champ, path = :value)
    case path
    when :value
      filled_champ_value(champ)
    when :departement
      champ.departement_code_and_name || ''
    when :code
      champ.code || ''
    end
  end

  def filled_champ_value_for_tag(champ, path = :value)
    case path
    when :value
      filled_champ_value(champ)
    when :departement
      champ.departement_code_and_name || ''
    when :code
      champ.code || ''
    end
  end

  def filled_champ_value(champ)
    champ.code_postal? ? "#{champ.name} (#{champ.code_postal})" : champ.name
  end

  def columns(procedure_id:, displayable: true, prefix: nil)
    addressable_columns(procedure_id:, displayable:, prefix:)
      .concat(legacy_columns(procedure_id:, prefix:))
  end

  def personnalisation_column(procedure_id:)
    addressable_columns(procedure_id:, only: [:city_name]).first
  end

  def info_columns(procedure:)
    Dossiers::CommuneComponent.data_labels
  end

  private

  # Anciennes colonnes conservées pour rester résolvables par les
  # ProcedurePresentation / exports / colonnes graphql persistées avant la bascule sur AddressableColumnConcern.
  def legacy_columns(procedure_id:, prefix:)
    [
      Columns::ChampColumn.new(
        procedure_id:,
        stable_id:,
        tdc_type: type_champ,
        label: libelle_with_prefix(prefix),
        type: :text,
        displayable: false,
        filterable: false,
        options_for_select:,
        mandatory: mandatory?
      ),
    ] +
    [
      ['code postal (5 chiffres)', '$.code_postal', :text],
      ['département', '$.code_departement', :number],
    ].map do |(label, jsonpath, type)|
      Columns::JSONPathColumn.new(
        procedure_id:,
        stable_id:,
        tdc_type: type_champ,
        label: "#{libelle_with_prefix(prefix)} - #{label}",
        jsonpath:,
        displayable: false,
        filterable: false,
        type:,
        mandatory: mandatory?
      )
    end
  end

  def paths
    paths = super
    paths.push({
      libelle: "#{libelle} (Code INSEE)",
      description: "#{description} (Code INSEE)",
      path: :code,

    })
    paths.push({
      libelle: "#{libelle} (Département)",
      description: "#{description} (Département)",
      path: :departement,

    })
    paths
  end
end
