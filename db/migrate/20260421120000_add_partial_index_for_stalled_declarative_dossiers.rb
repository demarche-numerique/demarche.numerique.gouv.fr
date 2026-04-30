# frozen_string_literal: true

class AddPartialIndexForStalledDeclarativeDossiers < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :dossiers,
              :revision_id,
              name: 'index_dossiers_stalled_declarative',
              where: "state = 'en_construction' AND declarative_triggered_at IS NULL",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
