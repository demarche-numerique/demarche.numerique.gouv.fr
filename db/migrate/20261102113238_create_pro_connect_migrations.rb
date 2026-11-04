# frozen_string_literal: true

class CreateProConnectMigrations < ActiveRecord::Migration[8.1]
  def change
    create_table :pro_connect_migrations do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :source_email, null: false
      t.references :parent, foreign_key: { to_table: :pro_connect_migrations, on_delete: :cascade }
      t.string :state, null: false, default: 'started'
      t.string :pro_connect_email
      t.string :code_digest
      t.datetime :code_sent_at
      t.integer :code_attempts, null: false, default: 0
      t.references :target_user, foreign_key: { to_table: :users, on_delete: :nullify }
      t.bigint :procedure_ids, array: true
      t.bigint :groupe_instructeur_ids, array: true
      t.boolean :shared # rubocop:disable Rails/ThreeStateBooleanColumn
      t.timestamps
    end

    add_index :pro_connect_migrations, :source_email, where: "state = 'renamed'"
  end
end
