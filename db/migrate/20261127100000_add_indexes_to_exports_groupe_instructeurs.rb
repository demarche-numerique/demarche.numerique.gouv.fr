# frozen_string_literal: true

class AddIndexesToExportsGroupeInstructeurs < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :exports_groupe_instructeurs, [:groupe_instructeur_id, :export_id], algorithm: :concurrently
    add_index :exports_groupe_instructeurs, :export_id, algorithm: :concurrently
  end
end
