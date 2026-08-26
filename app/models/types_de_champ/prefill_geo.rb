# frozen_string_literal: true

# Prefill screening for the champs backed by an APIGeoService referential
# (pays, regions, departements): a value is kept only when the champ setter
# would fully resolve it to a code and a name.
class TypesDeChamp::PrefillGeo < TypesDeChamp::Prefill
  def all_possible_values
    referential.sort_by { _1[:code] }.map { "#{_1[:code]} (#{_1[:name]})" }
  end

  private

  def screened_value(champ, value)
    return nil if !value.is_a?(String)

    value if resolve(value)&.resolved?
  end

  def resolve(value)
    case type_champ
    when TypeDeChamp.type_champs.fetch(:pays)
      APIGeoService.resolve_country(value)
    when TypeDeChamp.type_champs.fetch(:regions)
      APIGeoService.resolve_region(value)
    when TypeDeChamp.type_champs.fetch(:departements)
      APIGeoService.resolve_departement(value)
    end
  end

  def referential
    case type_champ
    when TypeDeChamp.type_champs.fetch(:pays)
      APIGeoService.countries
    when TypeDeChamp.type_champs.fetch(:regions)
      APIGeoService.regions
    when TypeDeChamp.type_champs.fetch(:departements)
      APIGeoService.departements
    end
  end
end
