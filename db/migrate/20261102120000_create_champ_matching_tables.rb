# frozen_string_literal: true

class CreateChampMatchingTables < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    create_table :procedure_user_overlaps do |t|
      t.references :left_procedure, null: false, index: false, foreign_key: { to_table: :procedures }
      t.references :right_procedure, null: false, foreign_key: { to_table: :procedures }
      t.integer :common_users_count, null: false
      t.datetime :champs_computed_at
      t.timestamps
    end

    add_index :procedure_user_overlaps, [:left_procedure_id, :right_procedure_id], unique: true, name: 'index_procedure_user_overlaps_on_pair'
    add_check_constraint :procedure_user_overlaps, 'left_procedure_id < right_procedure_id', name: 'procedure_user_overlaps_canonical_order'

    create_table :type_de_champ_matches do |t|
      t.bigint :left_procedure_id, null: false
      t.bigint :left_stable_id, null: false
      t.bigint :right_procedure_id, null: false
      t.bigint :right_stable_id, null: false
      t.integer :matching_users_count, null: false
      t.integer :common_users_count, null: false
      t.timestamps
    end

    add_index :type_de_champ_matches, [:left_procedure_id, :right_procedure_id, :left_stable_id, :right_stable_id], unique: true, name: 'index_type_de_champ_matches_on_champ_couple'

    add_foreign_key :type_de_champ_matches, :procedure_user_overlaps, column: [:left_procedure_id, :right_procedure_id], primary_key: [:left_procedure_id, :right_procedure_id], validate: false
    validate_foreign_key :type_de_champ_matches, :procedure_user_overlaps
  end
end
