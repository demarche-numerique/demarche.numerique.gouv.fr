# frozen_string_literal: true

class AddIndexToUsersRememberToken < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # Devise looks a token up by value on every remember-me sign in, and users is
  # large: without this it is a sequential scan behind a four way LEFT JOIN.
  def change
    add_index :users, :remember_token, unique: true, algorithm: :concurrently
  end
end
