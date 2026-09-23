# frozen_string_literal: true

class AddExpiresAtNullConstraintToUserSessions < ActiveRecord::Migration[8.0]
  # Unvalidated: adding it validated would scan the whole table under a lock.
  # The scan happens in the next migration, which only blocks other DDL.
  def change
    add_check_constraint :user_sessions,
                         'expires_at IS NOT NULL',
                         name: 'user_sessions_expires_at_null',
                         validate: false
  end
end
