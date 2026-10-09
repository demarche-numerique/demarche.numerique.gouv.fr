# frozen_string_literal: true

class AddGroupeInstructeurIndexesToDossierAssignments < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :dossier_assignments, :groupe_instructeur_id, algorithm: :concurrently, if_not_exists: true
    add_index :dossier_assignments, :previous_groupe_instructeur_id, algorithm: :concurrently, if_not_exists: true
  end
end
