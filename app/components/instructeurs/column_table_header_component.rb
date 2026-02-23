# frozen_string_literal: true

class Instructeurs::ColumnTableHeaderComponent < ApplicationComponent
  def initialize(procedure_presentation:)
    @procedure_presentation = procedure_presentation
    @columns = procedure_presentation.displayed_fields_for_headers
    @sorted_column = procedure_presentation.sorted_column
  end

  private

  def classname(column)
    return 'number-col' if column.dossier_id?
    return 'sva-col' if column.column == 'sva_svr_decision_on'
  end

  def column_header(column)
    id = column.id
    order = opposite_order_for(column)

    button_to(
      label_and_arrow(column),
      [:instructeur, @procedure_presentation],
      params: { sorted_column: { id: id, order: order } },
      class: 'fr-text--bold'
    )
  end

  def opposite_order_for(column)
    @sorted_column.column == column ? @sorted_column.opposite_order : 'asc'
  end

  def label_and_arrow(column)
    return column.human_label if @sorted_column.column != column

    @sorted_column.ascending? ? "#{column.human_label} ↑" : "#{column.human_label} ↓"
  end

  def aria_sort(column)
    return {} if @sorted_column.column != column

    @sorted_column.ascending? ? { "aria-sort": "ascending" } : { "aria-sort": "descending" }
  end
end
