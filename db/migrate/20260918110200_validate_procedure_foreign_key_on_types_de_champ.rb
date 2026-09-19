# frozen_string_literal: true

class ValidateProcedureForeignKeyOnTypesDeChamp < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :types_de_champ, :procedures
  end
end
