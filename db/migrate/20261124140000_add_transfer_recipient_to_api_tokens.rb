# frozen_string_literal: true

class AddTransferRecipientToAPITokens < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :api_tokens, :transfer_recipient, null: true, index: { algorithm: :concurrently }, foreign_key: false
  end
end
