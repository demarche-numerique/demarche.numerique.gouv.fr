# frozen_string_literal: true

class ValidateFranceConnectInformationForeignKeyOnUserSessions < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :user_sessions, :france_connect_informations
  end
end
