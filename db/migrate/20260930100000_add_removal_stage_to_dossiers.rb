# frozen_string_literal: true

# The removal of brouillons moves to an explicit stage and the date the
# current stage ends (#13915), starting with the trash. Both columns are
# nullable without default: NULL means the dossier is still handled by the
# legacy expiration columns, so adding them is a metadata-only change.
class AddRemovalStageToDossiers < ActiveRecord::Migration[8.1]
  def change
    add_column :dossiers, :removal_stage, :string
    add_column :dossiers, :removal_due_at, :datetime
  end
end
