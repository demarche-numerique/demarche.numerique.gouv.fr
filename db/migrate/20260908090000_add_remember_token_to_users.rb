# frozen_string_literal: true

class AddRememberTokenToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :remember_token, :string
  end
end
