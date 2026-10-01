# frozen_string_literal: true

class TypesDeChamp::CommuneTypeDeChamp < TypeDeChamp
  def self.category = LOCALISATION
  def self.icon = 'fr-icon-map-pin-line'
  def self.simple_routable? = true
  def self.conditionable? = true

  def prefillable? = true
  def customizable? = true
  def condition_value_type = :commune_enum
  def condition_options = APIGeoService.departement_options

  include AddressableColumnConcern

  def typed_champ_value_for_export(champ, path = :value)
    case path
    when :value
      typed_champ_value(champ)
    when :departement
      champ.departement_code_and_name || ''
    when :code
      champ.code || ''
    end
  end

  def typed_champ_value_for_tag(champ, path = :value)
    case path
    when :value
      typed_champ_value(champ)
    when :departement
      champ.departement_code_and_name || ''
    when :code
      champ.code || ''
    end
  end

  def typed_champ_value(champ)
    champ.postal_code? ? "#{champ.name} (#{champ.postal_code})" : champ.name
  end

  def columns(procedure_id:, displayable: true, prefix: nil)
    addressable_columns(procedure_id:, displayable:, prefix:, only: [*DEFAULT_ADDRESSABLE_COLUMNS, :city_code])
  end

  def customization_column(procedure_id:)
    addressable_columns(procedure_id:, only: [:city_name]).first
  end

  def info_columns(procedure:)
    Dossiers::CommuneComponent.data_labels
  end

  private

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
