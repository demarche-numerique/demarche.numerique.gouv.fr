# frozen_string_literal: true

class TypesDeChamp::DepartementTypeDeChamp < TypesDeChamp::TextTypeDeChamp
  def self.category = LOCALISATION
  def self.icon = 'fr-icon-map-pin-line'
  def self.column_type = :enum
  def self.simple_routable? = true
  def self.conditionable? = true

  def options_for_select = APIGeoService.departement_options
  def condition_value_type = :departement_enum
  def condition_options = APIGeoService.departement_options

  include AddressableColumnConcern

  def columns(procedure_id:, displayable: true, prefix: nil)
    addressable_columns(procedure_id:, displayable:, prefix:, only: [:department_code, :region_code])
  end

  def typed_champ_value(champ)
    "#{champ.code} – #{champ.name}"
  end

  def typed_champ_value_for_export(champ, path = :value)
    case path
    when :code
      champ.code
    when :value
      champ.name
    end
  end

  def typed_champ_value_for_tag(champ, path = :value)
    case path
    when :code
      champ.code
    when :value
      typed_champ_value(champ)
    end
  end

  def typed_champ_value_for_api(champ, version: 2)
    case version
    when 2
      typed_champ_value(champ).tr('–', '-')
    else
      typed_champ_value(champ)
    end
  end

  def info_columns(procedure:)
    Dossiers::DepartementComponent.data_labels
  end

  private

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
