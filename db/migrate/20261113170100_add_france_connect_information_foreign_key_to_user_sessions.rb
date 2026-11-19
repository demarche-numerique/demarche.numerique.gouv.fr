# frozen_string_literal: true

class AddFranceConnectInformationForeignKeyToUserSessions < ActiveRecord::Migration[8.1]
  def change
    # An usager may detach an identity from the account: the sessions it opened stay
    add_foreign_key :user_sessions, :france_connect_informations, on_delete: :nullify, validate: false
  end
end
