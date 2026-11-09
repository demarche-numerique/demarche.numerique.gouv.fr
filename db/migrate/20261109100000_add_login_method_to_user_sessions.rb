# frozen_string_literal: true

class AddLoginMethodToUserSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :user_sessions, :login_method, :string
  end
end
