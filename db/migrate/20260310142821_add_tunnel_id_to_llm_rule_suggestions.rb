# frozen_string_literal: true

class AddTunnelIdToLLMRuleSuggestions < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :llm_rule_suggestions, :tunnel_id, :string, limit: 6
    add_index :llm_rule_suggestions, :tunnel_id, algorithm: :concurrently
    add_index :llm_rule_suggestions, [:procedure_revision_id, :tunnel_id], algorithm: :concurrently
  end
end
