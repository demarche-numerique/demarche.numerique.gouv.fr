# frozen_string_literal: true

# Cron::BrouillonRemovalReconciliationJob (#13915) counts the dossiers which
# kept a removal stage or due date while their state leaves their removal to
# the legacy columns. The index on (removal_stage, removal_due_at) leaves out
# the rows without a due date, so that count would read the 11 M other
# dossiers. This index only holds the rows breaking the rule: empty in steady
# state, it costs nothing to maintain.
class AddRemovalStageUnmanagedIndexToDossiers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Dossier::REMOVAL_MANAGED_STATES as it stands today, copied rather than
  # read: a migration keeps the schema it ran with. Adding a state to the
  # constant needs another index, and the reconciliation spec fails until it
  # ships.
  MANAGED_STATES = ['brouillon'].freeze

  def change
    add_index :dossiers, :id,
      name: "index_dossiers_removal_stage_unmanaged",
      where: "state NOT IN (#{MANAGED_STATES.map { connection.quote(it) }.join(', ')}) AND (removal_stage IS NOT NULL OR removal_due_at IS NOT NULL)",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
