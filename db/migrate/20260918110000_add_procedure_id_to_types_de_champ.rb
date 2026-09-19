# frozen_string_literal: true

class AddProcedureIdToTypesDeChamp < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :types_de_champ, :procedure, null: true, index: { algorithm: :concurrently }, foreign_key: false
  end
end
