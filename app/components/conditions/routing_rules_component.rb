# frozen_string_literal: true

class Conditions::RoutingRulesComponent < Conditions::ConditionsComponent
  include Logic

  def initialize(groupe_instructeur:)
    @groupe_instructeur = groupe_instructeur
    @condition = groupe_instructeur.routing_rule || empty_operator(empty, empty)
    @procedure = groupe_instructeur.procedure
    @procedure_id = @procedure.id
    @source_tdcs = @procedure.active_revision.types_de_champ_public
    @champ_value_in_condition = @procedure.champ_value_in_condition?
  end

  private

  def add_condition_path
    add_row_admin_procedure_routing_rule_path(@procedure_id, @groupe_instructeur.id)
  end

  def delete_condition_path(row_index)
    delete_row_admin_procedure_routing_rule_path(@procedure_id, @groupe_instructeur.id, row_index: row_index)
  end

  def input_id_for(name, row_index)
    "#{@groupe_instructeur.id}-#{name}-#{row_index}"
  end

  def input_prefix
    'groupe_instructeur[condition_form]'
  end
end
