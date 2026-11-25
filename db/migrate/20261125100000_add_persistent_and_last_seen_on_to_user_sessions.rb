# frozen_string_literal: true

class AddPersistentAndLastSeenOnToUserSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :user_sessions, :persistent, :boolean, default: false, null: false
    add_column :user_sessions, :last_seen_on, :date
  end
end
