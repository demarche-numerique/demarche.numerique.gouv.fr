# frozen_string_literal: true

class AddRequiresIPFilteringToAPITokens < ActiveRecord::Migration[8.0]
  def change
    add_column :api_tokens, :requires_ip_filtering, :boolean, default: false, null: false
  end
end
