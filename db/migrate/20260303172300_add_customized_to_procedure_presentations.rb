# frozen_string_literal: true

class AddCustomizedToProcedurePresentations < ActiveRecord::Migration[7.2]
  def change
    add_column :procedure_presentations, :customized, :boolean, default: false, null: false
  end
end
