# frozen_string_literal: true

class TypesDeChamp::PrefillCommune < TypesDeChamp::Prefill
  def all_possible_values
    []
  end

  def example_value
    departement_code = departements.pick(:code)
    APIGeoService.communes(departement_code).pick(:postal_code, :code)
  end

  def to_assignable_attributes(champ, value)
    return if value.blank? || !value.is_a?(Array)
    return if (postal_code = value.first).blank?
    return if APIGeoService.communes_by_postal_code(postal_code).empty?
    return if !value.one? && (commune_code = value.second).blank?
    return if !value.one? && !APIGeoService.communes_by_postal_code(postal_code).any? { _1[:code] == commune_code }

    if value.one?
      code_postal_attributes(postal_code)
    else
      code_postal_and_commune_attributes(postal_code, commune_code)
    end
  end

  private

  def code_postal_attributes(postal_code)
    {
      code_postal: postal_code,
    }
  end

  def code_postal_and_commune_attributes(postal_code, commune_code)
    code_postal_attributes(postal_code).merge(external_id: commune_code)
  end

  def departements
    @departements ||= APIGeoService.departements.sort_by { _1[:code] }
  end
end
