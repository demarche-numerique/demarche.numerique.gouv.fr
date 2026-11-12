# frozen_string_literal: true

class AddIndexOnEmailEventsTo < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :email_events, :to, algorithm: :concurrently
  end
end
