# frozen_string_literal: true

class AddTypeDeChampTreeToProcedureRevisions < ActiveRecord::Migration[8.1]
  def change
    add_column :procedure_revisions, :type_de_champ_tree, :jsonb
  end
end
