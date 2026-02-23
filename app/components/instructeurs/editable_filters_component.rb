# frozen_string_literal: true

class Instructeurs::EditableFiltersComponent < ApplicationComponent
  attr_reader :procedure_presentation, :statut, :instructeur_procedure

  def initialize(procedure_presentation:, instructeur_procedure:, statut:)
    @procedure_presentation = procedure_presentation
    @instructeur_procedure = instructeur_procedure
    @statut = statut
  end

  def id
    "editable-filters-component"
  end

  def delete_button(filter)
    button_to(
      remove_filter_instructeur_procedure_presentation_path(@procedure_presentation),
      method: :delete,
      class: 'fr-btn fr-btn--sm fr-btn--tertiary-no-outline fr-icon-delete-line',
      params: {
        filter: { id: filter.column.id, filter: filter.filter },
        statut: @statut,
      }.compact,
      form: { data: { turbo: true } },
      form_class: 'inline'
    ) do
      t('.clear_filter', filter_label: filter.human_label)
    end
  end

  def filters
    procedure_presentation.filters_for(statut)
  end
end
