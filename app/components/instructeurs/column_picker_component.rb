# frozen_string_literal: true

class Instructeurs::ColumnPickerComponent < ApplicationComponent
  attr_reader :procedure, :procedure_presentation

  def initialize(procedure:, procedure_presentation:)
    @procedure = procedure
    @procedure_presentation = procedure_presentation
    @displayable_columns_for_select, @displayable_columns_selected = displayable_columns_for_select
  end

  def displayable_columns_for_select
    [
      procedure.columns.filter(&:displayable).map { |column| [column.human_label, column.id] },
      procedure_presentation.displayed_columns.map(&:id),
    ]
  end
end
