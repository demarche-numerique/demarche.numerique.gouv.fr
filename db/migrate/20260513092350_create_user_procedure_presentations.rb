# frozen_string_literal: true

class CreateUserProcedurePresentations < ActiveRecord::Migration[7.2]
  def change
    create_table :user_procedure_presentations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :procedure, null: false, foreign_key: true
      t.jsonb :displayed_columns, array: true, null: false, default: []

      t.timestamps
    end

    add_index :user_procedure_presentations, [:user_id, :procedure_id], unique: true
  end
end
