# frozen_string_literal: true

class Conditions::IneligibiliteRulesComponent < Conditions::ConditionsComponent
  include Logic

  def initialize(draft_revision:)
    @draft_revision = draft_revision
    @procedure = draft_revision.procedure
    @published_revision = @procedure.published_revision
    @condition = draft_revision.ineligibilite_rules
    @source_tdcs = draft_revision.types_de_champ_for(scope: :public)
    @procedure_id = @procedure.id
    @champ_value_in_condition = @procedure.champ_value_in_condition?
  end

  def pending_changes?
    return false if !@published_revision

    !@published_revision.compare_ineligibilite_rules(@draft_revision).empty?
  end

  private

  def input_prefix
    'procedure_revision[condition_form]'
  end

  def input_id_for(name, row_index)
    "#{@draft_revision.id}-#{name}-#{row_index}"
  end

  def delete_condition_path(row_index)
    delete_row_admin_procedure_ineligibilite_rules_path(@draft_revision.procedure_id, revision_id: @draft_revision.id, row_index:)
  end

  def add_condition_path
    add_row_admin_procedure_ineligibilite_rules_path(@draft_revision.procedure_id, revision_id: @draft_revision.id)
  end
end
