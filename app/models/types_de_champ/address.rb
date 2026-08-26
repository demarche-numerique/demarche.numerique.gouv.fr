# frozen_string_literal: true

class TypesDeChamp::Address < TypesDeChamp::Text
  def self.category = LOCALISATION
  def self.simple_routable? = true
  def self.conditionable? = true

  def condition_value_type = :address
  def condition_options = APIGeoService.departement_options

  include AddressableColumnConcern

  def libelles_for_export
    path = paths.first
    [[path[:libelle], path[:path]]]
  end

  def typed_champ_value(champ)
    champ.address_label.presence || ''
  end

  def typed_champ_value_for_api(champ, version: 2)
    typed_champ_value(champ)
  end

  def typed_champ_value_for_tag(champ, path = :value)
    case path
    when :value
      typed_champ_value(champ)
    when :departement
      champ.departement_code_and_name || ''
    when :commune
      champ.commune_name || ''
    end
  end

  def typed_champ_value_for_export(champ, path = :value)
    case path
    when :value
      typed_champ_value(champ)
    when :departement
      champ.departement_code_and_name
    when :commune
      champ.commune_name
    end
  end

  def typed_champ_blank?(champ)
    if champ.migrated_legacy_address?
      champ.value.blank?
    else
      !champ.full_address?
    end
  end

  def canonical_column(procedure_id:, displayable: true, prefix: nil)
    Columns::AddressColumn.new(
      procedure_id:,
      stable_id:,
      tdc_type: type_champ,
      label: libelle_with_prefix(prefix),
      type: self.class.column_type,
      displayable:,
      mandatory: mandatory?
    )
  end

  def columns(procedure_id:, displayable: true, prefix: nil)
    super.concat(addressable_columns(procedure_id:, displayable:, prefix:, deprecated_columns: true))
  end

  def info_columns(procedure:)
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
