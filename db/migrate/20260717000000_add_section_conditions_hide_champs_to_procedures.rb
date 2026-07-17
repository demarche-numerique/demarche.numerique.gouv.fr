# frozen_string_literal: true

class AddSectionConditionsHideChampsToProcedures < ActiveRecord::Migration[8.0]
  def change
    add_column :procedures, :section_conditions_hide_champs, :boolean, default: false, null: false
  end
end
