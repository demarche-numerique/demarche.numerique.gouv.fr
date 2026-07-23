# frozen_string_literal: true

class CreateWebhookEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :webhook_events do |t|
      t.references :procedure, null: false, foreign_key: true, index: false
      # No foreign key: events must survive dossier deletion (dossier_supprime)
      t.bigint :dossier_id, null: false
      t.string :event_type, null: false
      t.datetime :created_at, null: false
    end

    # (procedure_id, id) serves the per-procedure max(id) cursor lookups;
    # (procedure_id, event_type, id) turns the pending-events checks (which
    # filter on subscribed event types) into per-type range probes instead of
    # scans of the whole post-cursor tail.
    add_index :webhook_events, [:procedure_id, :id]
    add_index :webhook_events, [:procedure_id, :event_type, :id]
    add_index :webhook_events, :created_at
  end
end
