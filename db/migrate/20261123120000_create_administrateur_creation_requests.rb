# frozen_string_literal: true

class CreateAdministrateurCreationRequests < ActiveRecord::Migration[8.1]
  def change
    # No foreign keys to super_admins: the log must outlive a deleted super admin.
    create_table :administrateur_creation_requests do |t|
      t.bigint :requester_id, null: false
      t.bigint :validator_id
      t.string :emails, array: true, null: false
      t.string :state, null: false
      t.boolean :otp_verified, null: false, default: false
      t.jsonb :results, null: false, default: {}
      t.datetime :decided_at
      t.timestamps

      t.index [:requester_id, :created_at]
    end
  end
end
