# frozen_string_literal: true

class CreateWebhookEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :webhook_events do |t|
      t.references :procedure, null: false, foreign_key: true, index: false
      # no foreign key: events outlive the dossier
      t.bigint :dossier_id, null: false
      t.string :event_type, null: false
      t.datetime :created_at, null: false
    end

    add_index :webhook_events, [:procedure_id, :id]
    add_index :webhook_events, [:procedure_id, :event_type, :id]
    add_index :webhook_events, :created_at
  end
end
