# frozen_string_literal: true

class AddProcedureForeignKeyToTypesDeChamp < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :types_de_champ, :procedures, validate: false
  end
end
