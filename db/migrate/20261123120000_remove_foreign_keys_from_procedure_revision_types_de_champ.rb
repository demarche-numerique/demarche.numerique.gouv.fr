# frozen_string_literal: true

# The table is no longer written nor read: the revisions store their tree
# (procedure_revisions.type_de_champ_tree). The rows left in it would keep a
# revision or a type de champ from being destroyed, until the table is dropped.
class RemoveForeignKeysFromProcedureRevisionTypesDeChamp < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :procedure_revision_types_de_champ, :procedure_revisions, column: :revision_id
    remove_foreign_key :procedure_revision_types_de_champ, :types_de_champ
    remove_foreign_key :procedure_revision_types_de_champ, :procedure_revision_types_de_champ, column: :parent_id
  end
end
