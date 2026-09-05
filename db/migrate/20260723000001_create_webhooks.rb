# frozen_string_literal: true

class CreateWebhooks < ActiveRecord::Migration[8.0]
  def change
    create_table :webhooks do |t|
      t.references :procedure, null: false, foreign_key: true
      t.string :url, null: false
      t.string :secret, null: false
      t.string :label
      t.string :event_types, array: true, null: false, default: []
      t.boolean :enabled, null: false, default: true
      t.bigint :cursor, null: false, default: 0
      t.jsonb :event_type_floors, null: false, default: {}
      t.integer :consecutive_failures, null: false, default: 0
      t.datetime :last_attempt_at
      t.datetime :last_success_at
      t.string :last_error
      t.datetime :auto_disabled_at
      t.datetime :delivery_claimed_at

      t.timestamps
    end
  end
end
