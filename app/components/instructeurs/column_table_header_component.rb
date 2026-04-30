# frozen_string_literal: true

class Instructeurs::ColumnTableHeaderComponent < ApplicationComponent
  def initialize(procedure_presentation:, displayed_columns:)
    @procedure_presentation = procedure_presentation
    @procedure = procedure_presentation.procedure
    @columns = build_header_columns(displayed_columns)
    @sorted_column = procedure_presentation.sorted_column
  end

  private

  def build_header_columns(displayed_columns)
    header_columns = [
      @procedure.dossier_id_column,
      *displayed_columns,
      @procedure.dossier_state_column,
    ]
    header_columns.concat(@procedure.sva_svr_columns.filter(&:displayable)) if @procedure.sva_svr_enabled?
    header_columns
  end

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
    return column.label if @sorted_column.column != column

    @sorted_column.ascending? ? "#{column.label} ↑" : "#{column.label} ↓"
  end

  def aria_sort(column)
    return {} if @sorted_column.column != column

    @sorted_column.ascending? ? { "aria-sort": "ascending" } : { "aria-sort": "descending" }
  end
end
