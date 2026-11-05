# frozen_string_literal: true

class AddBrevoBlockToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :brevo_blocked_reason, :string
    add_column :users, :brevo_blocked_reason_at, :datetime
    add_column :users, :brevo_last_blocked_at, :datetime
    add_column :users, :brevo_unblocked_at, :datetime
  end
end
