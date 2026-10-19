# frozen_string_literal: true

class AddTokenDigestToAPITokens < ActiveRecord::Migration[8.1]
  def change
    add_column :api_tokens, :token_digest, :string
  end
end
