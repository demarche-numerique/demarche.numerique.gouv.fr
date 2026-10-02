# frozen_string_literal: true

class Instructeurs::ColumnPickerComponent < ApplicationComponent
  attr_reader :procedure, :procedure_presentation, :instructeur

  def initialize(procedure:, procedure_presentation:, instructeur:)
    @procedure = procedure
    @procedure_presentation = procedure_presentation
    @instructeur = instructeur
    @displayable_columns_for_select, @displayable_columns_selected = displayable_columns_for_select
  end

  def displayable_columns_for_select
    [
      procedure.columns.filter(&:displayable).map { |column| [column.label, column.id] },
      procedure_presentation.effective_displayed_columns.map(&:id),
    ]
  end

  def instructeur_is_admin?
    admin = instructeur.user.administrateur
    admin.present? && admin.owns?(procedure)
  end

  def default_presentation_active?
    procedure.admin_default_procedure_presentation_active
  end

  def default_presentation
    return @default_presentation if defined?(@default_presentation)

    @default_presentation = ProcedurePresentation.find_by(id: procedure.admin_default_procedure_presentation_id)
  end

  def default_admin
    default_presentation&.instructeur
  end

  def owner_of_default_presentation?
    return false if !default_presentation

    default_presentation.id ==
      instructeur.procedure_presentation_for_procedure_id(procedure.id)&.id
  end

  def another_admin_active_default_presentation?
    instructeur_is_admin? &&
      default_presentation_active? &&
      !owner_of_default_presentation?
  end

  def toggle_disabled?
    another_admin_active_default_presentation?
  end

  def toggle_checked?
    default_presentation_active? && owner_of_default_presentation?
  end

  def show_reset_to_admin_default?
    default_presentation_active? &&
      procedure_presentation.customized &&
      procedure.admin_default_procedure_presentation_id != procedure_presentation.id
  end

  def reset_to_admin_default_form_id
    dom_id(procedure_presentation, :reset_to_admin_default)
  end
end
