# frozen_string_literal: true

class EditableChamp::EpciComponent < EditableChamp::EditableChampBaseComponent
  include ApplicationHelper

  def dsfr_champ_container
    :fieldset
  end

  private

  def departement_options
    APIGeoService.departements.filter(&method(:departement_with_epci?)).map { ["#{_1[:code]} – #{_1[:name]}", _1[:code]] }
  end

  def epci_options
    if @champ.departement?
      APIGeoService.epcis(@champ.department_code).map { ["#{_1[:code]} – #{_1[:name]}", _1[:code]] }
    else
      []
    end
  end

  # An EPCI picked from the old list while the new departement is being saved
  # is not in the new list: show « Sélectionnez » instead.
  def selected_epci_code
    @champ.code if epci_options.any? { |_label, code| code == @champ.code }
  end

  def departement_with_epci?(departement)
    code = departement[:code]
    !code.start_with?('98') && !code.in?(['99', '975', '977', '978'])
  end
end
