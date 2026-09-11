# frozen_string_literal: true

class AddIPAddressToUserSessions < ActiveRecord::Migration[8.0]
  def change
    # `inet` rather than a string: Postgres validates the value and stores IPv4
    # and IPv6 alike, and Rails casts it back to an IPAddr.
    add_column :user_sessions, :ip_address, :inet
  end
end
