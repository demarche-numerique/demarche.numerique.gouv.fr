# frozen_string_literal: true

class TypesDeChamp::PrefillEpci < TypesDeChamp::Prefill
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

    code_departement = value.first
    return nil if APIGeoService.departement_name(code_departement).blank?

    epci_code = value.second
    return { code_departement:, value: nil } if epci_code.blank?
    return nil if APIGeoService.epci_name(code_departement, epci_code).blank?

    { code_departement:, value: epci_code }
  end

  private

  def departements
    @departements ||= APIGeoService.departements.sort_by { |departement| departement[:code] }
  end
end
