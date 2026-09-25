# frozen_string_literal: true

class TypesDeChamp::PrefillEpciTypeDeChamp < TypesDeChamp::PrefillTypeDeChamp
  def all_possible_values
    departements.map do |departement|
      "#{departement[:code]} (#{departement[:name]}) : https://geo.api.gouv.fr/epcis?codeDepartement=#{departement[:code]}"
    end
  end

  def example_value
    departement_code = departements.pick(:code)
    epci_code = APIGeoService.epcis(departement_code).pick(:code)
    [departement_code, epci_code]
  end

  def to_assignable_attributes(champ, value)
    return nil if value.blank? || !value.is_a?(Array)

    department_code = value.first
    return nil if APIGeoService.departement_name(department_code).blank?

    epci_code = value.second
    return { department_code:, value: nil } if epci_code.blank?
    return nil if APIGeoService.epci_name(department_code, epci_code).blank?

    { department_code:, value: epci_code }
  end

  private

  def departements
    @departements ||= APIGeoService.departements.sort_by { |departement| departement[:code] }
  end
end
