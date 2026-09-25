# frozen_string_literal: true

class AddTrustedDeviceVersionToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :trusted_device_version, :integer, default: 0, null: false
  end
end
