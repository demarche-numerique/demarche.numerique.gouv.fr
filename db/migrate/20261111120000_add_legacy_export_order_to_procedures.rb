# frozen_string_literal: true

class AddLegacyExportOrderToProcedures < ActiveRecord::Migration[8.1]
  def change
    # the procedures existing now keep the order of their exports, the ones
    # created from now on follow the form
    add_column :procedures, :legacy_export_order, :boolean, default: true, null: false
    change_column_default :procedures, :legacy_export_order, from: true, to: false
  end
end
