# frozen_string_literal: true

class TypesDeChamp::AddressTypeDeChamp < TypesDeChamp::TextTypeDeChamp
  include AddressableColumnConcern

  def libelles_for_export
    path = paths.first
    [[path[:libelle], path[:path]]]
  end

  def filled_champ_value(champ)
    champ.address_label.presence || ''
  end

  def filled_champ_value_for_api(champ, version: 2)
    filled_champ_value(champ)
  end

  def filled_champ_value_for_tag(champ, path = :value)
    case path
    when :value
      filled_champ_value(champ)
    when :departement
      champ.departement_code_and_name || ''
    when :commune
      champ.commune_name || ''
    end
  end

  def filled_champ_value_for_export(champ, path = :value)
    case path
    when :value
      filled_champ_value(champ)
    when :departement
      champ.departement_code_and_name
    when :commune
      champ.commune_name
    end
  end

  def champ_value_blank?(champ)
    if champ.migrated_legacy_address?
      champ.value.blank?
    else
      !champ.full_address?
    end
  end

  def canonical_column(displayable: true, prefix: nil)
    Columns::AddressColumn.new(
      procedure_id:,
      stable_id:,
      tdc_type: type_champ,
      label: libelle_with_prefix(prefix),
      type: TypeDeChamp.column_type(type_champ),
      displayable:,
      mandatory: mandatory?
    )
  end

  def columns(displayable: true, prefix: nil)
    super.concat(addressable_columns(displayable:, prefix:, deprecated_columns: true))
  end

  def info_columns
    Dossiers::AddressComponent.data_labels
  end

  private

  def paths
    paths = super
    paths.push(
      {
        libelle: "#{libelle} (Département)",
        path: :departement,
        description: "#{description} (Département)",
      },
      {
        libelle: "#{libelle} (Commune)",
        path: :commune,
        description: "#{description} (Commune)",
      }
    )
    paths
  end
end
