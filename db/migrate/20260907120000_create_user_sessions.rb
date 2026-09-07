# frozen_string_literal: true

class CreateUserSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_sessions, id: :uuid do |t|
      t.references :sessionable, polymorphic: true, null: false, type: :bigint, index: false
      t.datetime :expires_at
      t.datetime :revoked_at
      t.string :revoked_reason
      t.string :user_agent
      t.timestamps

      # Named: the default would exceed PostgreSQL's 63 character limit.
      t.index [:sessionable_type, :sessionable_id, :revoked_at],
        name: 'index_user_sessions_on_sessionable_and_revoked_at'
    end
  end
end
