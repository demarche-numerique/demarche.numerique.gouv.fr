# frozen_string_literal: true

class ValidateExpiresAtNullConstraintOnUserSessions < ActiveRecord::Migration[8.0]
  # Every row carries a deadline by now: one is written when the session opens,
  # and T20260923BackfillUserSessionExpiryTask gave one to the rows that
  # predated deadlines, a deploy earlier.
  def change
    validate_check_constraint :user_sessions, name: 'user_sessions_expires_at_null'

    change_column_null :user_sessions, :expires_at, false
    remove_check_constraint :user_sessions, 'expires_at IS NOT NULL', name: 'user_sessions_expires_at_null'
  end
end
