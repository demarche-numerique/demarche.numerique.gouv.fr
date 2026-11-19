# frozen_string_literal: true

class AddFranceConnectInformationIdToUserSessions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :user_sessions, :france_connect_information, null: true, index: { algorithm: :concurrently }, foreign_key: false
  end
end
