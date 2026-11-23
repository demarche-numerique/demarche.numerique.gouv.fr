# frozen_string_literal: true

class AddFollowsClonesToAPITokens < ActiveRecord::Migration[8.1]
  def change
    add_column :api_tokens, :follows_clones, :boolean, default: false, null: false
  end
end
