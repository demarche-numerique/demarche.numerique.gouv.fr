# frozen_string_literal: true

class TypesDeChamp::PaysTypeDeChamp < TypesDeChamp::TextTypeDeChamp
  def self.category = LOCALISATION
  def self.icon = 'fr-icon-earth-line'
  def self.column_type = :enum
  def self.simple_routable? = true
  def self.conditionable? = true

  def options_for_select = APIGeoService.country_options
  def condition_value_type = :enum
  def condition_options = APIGeoService.countries.map { ["#{_1[:name]} – #{_1[:code]}", _1[:code]] }

  def typed_champ_value(champ)
    champ.name
  end

  def typed_champ_value_for_tag(champ, path = :value)
    case path
    when :value
      typed_champ_value(champ)
    when :code
      champ.code
    end
  end

  def typed_champ_blank?(champ)
    champ.value.blank? && champ.external_id.blank?
  end

  # bare name and code; the catalogue only has the name
  def legacy_export_columns(procedure_id:)
    code = canonical_column(procedure_id:)

    [
      legacy_export_column(procedure_id:, label: libelle, columns: code) { APIGeoService.country_name(it) if it },
      legacy_export_column(procedure_id:, label: "#{libelle} (Code)", columns: code),
    ]
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
