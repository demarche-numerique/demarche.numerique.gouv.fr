# frozen_string_literal: true

class AddFranceConnectPlusRequiredToProcedures < ActiveRecord::Migration[8.1]
  def change
    add_column :procedures, :france_connect_plus_required, :boolean, default: false, null: false
  end
end
