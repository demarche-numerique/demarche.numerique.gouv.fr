# frozen_string_literal: true

# The nightly brouillon crons select the dossiers whose current stage is over:
# WHERE removal_stage = ? AND removal_due_at <= ?. Only brouillons carry a due
# date, hence the partial index.
class AddRemovalIndexToDossiers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :dossiers, [:removal_stage, :removal_due_at],
              where: "removal_due_at IS NOT NULL",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
