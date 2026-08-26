# frozen_string_literal: true

class TypesDeChamp::Pays < TypesDeChamp::Text
  def self.category = LOCALISATION
  def self.column_type = :enum
  def self.simple_routable? = true
  def self.conditionable? = true

  def options_for_select = APIGeoService.country_options
  def condition_value_type = :enum
  def condition_options = APIGeoService.countries.map { ["#{_1[:name]} – #{_1[:code]}", _1[:code]] }

  def typed_champ_value(champ)
    champ.name
  end

  def typed_champ_value_for_export(champ, path = :value)
    case path
    when :value
      typed_champ_value(champ)
    when :code
      champ.code
    end
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
