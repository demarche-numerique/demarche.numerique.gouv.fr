# frozen_string_literal: true

class EditableChamp::EpciComponent < EditableChamp::EditableChampBaseComponent
  include ApplicationHelper
  delegate :departement?, to: :@champ
  def dsfr_champ_container
    :fieldset
  end

  # small trick here.
  # EPCI champ is a compound input. one input for departement, one for epci.
  # focusable error does not point to the same input.
  # if no departement selected, focusable error points to departement input
  # if a departement is selected, focusable error points to epci input
  def focusable_departement_input_id
    if !departement?
      @champ.focusable_input_id(:value) # must be focusable when no departement is selected
    else
      @champ.focusable_input_id(:department_code) # otherwise, use same as error name
    end
  end

  def focusable_epci_input_id
    if departement?
      @champ.focusable_input_id(:value)
    else
      @champ.focusable_input_id(:not_visible_do_not_care)
    end
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

  def departement_select_options
    { selected: @champ.department_code }.merge(@champ.mandatory? ? { prompt: t('views.components.select_list') } : { include_blank: t('views.components.select_list') })
  end

  def epci_select_options
    { selected: @champ.code }.merge(@champ.mandatory? ? { prompt: t('views.components.select_list') } : { include_blank: t('views.components.select_list') })
  end

  def departement_with_epci?(departement)
    code = departement[:code]
    !code.start_with?('98') && !code.in?(['99', '975', '977', '978'])
  end
end
