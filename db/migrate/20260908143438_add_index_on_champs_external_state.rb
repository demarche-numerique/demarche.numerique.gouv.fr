# frozen_string_literal: true

class AddIndexOnChampsExternalState < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Cron::RetryDegradedSiretChampJob scans this every 2 hours. Partial, because
  # only a handful of champs are degraded outside an outage.
  def change
    add_index :champs, :id,
      where: "external_state = 'degraded'",
      name: 'index_champs_on_degraded_external_state',
      algorithm: :concurrently
  end
end
