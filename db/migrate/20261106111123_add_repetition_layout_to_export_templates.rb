# frozen_string_literal: true

class AddRepetitionLayoutToExportTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :export_templates, :repetition_layout, :string, default: 'sheet', null: false
  end
end
