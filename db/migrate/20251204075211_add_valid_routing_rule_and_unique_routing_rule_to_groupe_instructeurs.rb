# frozen_string_literal: true

class AddValidRoutingRuleAndUniqueRoutingRuleToGroupeInstructeurs < ActiveRecord::Migration[7.2]
  def change
    add_column :groupe_instructeurs, :valid_routing_rule, :boolean, default: false, null: false
    add_column :groupe_instructeurs, :unique_routing_rule, :boolean, default: false, null: false
  end
end
