# frozen_string_literal: true

class AddCheckConstraintOnTypesDeChampProcedureId < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :types_de_champ, "procedure_id IS NOT NULL", name: "types_de_champ_procedure_id_null", validate: false
  end
end
