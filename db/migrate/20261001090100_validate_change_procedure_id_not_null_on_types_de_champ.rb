# frozen_string_literal: true

class ValidateChangeProcedureIdNotNullOnTypesDeChamp < ActiveRecord::Migration[8.1]
  def up
    validate_check_constraint :types_de_champ, name: "types_de_champ_procedure_id_null"
    change_column_null :types_de_champ, :procedure_id, false
    remove_check_constraint :types_de_champ, name: "types_de_champ_procedure_id_null"
  end

  def down
    add_check_constraint :types_de_champ, "procedure_id IS NOT NULL", name: "types_de_champ_procedure_id_null", validate: false
    change_column_null :types_de_champ, :procedure_id, true
  end
end
