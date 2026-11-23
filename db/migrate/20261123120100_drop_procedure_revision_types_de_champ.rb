# frozen_string_literal: true

# Where a type de champ sat in a revision, before the revisions stored their
# tree (procedure_revisions.type_de_champ_tree).
class DropProcedureRevisionTypesDeChamp < ActiveRecord::Migration[8.1]
  def change
    drop_table :procedure_revision_types_de_champ do |t|
      t.bigint :parent_id
      t.integer :position, null: false
      t.bigint :revision_id, null: false
      t.bigint :type_de_champ_id, null: false
      t.timestamps precision: nil

      t.index :parent_id
      t.index :revision_id
      t.index :type_de_champ_id
    end
  end
end
