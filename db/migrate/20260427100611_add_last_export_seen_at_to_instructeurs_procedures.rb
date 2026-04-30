# frozen_string_literal: true

class AddLastExportSeenAtToInstructeursProcedures < ActiveRecord::Migration[7.2]
  def change
    add_column :instructeurs_procedures, :last_export_seen_at, :datetime
  end
end
