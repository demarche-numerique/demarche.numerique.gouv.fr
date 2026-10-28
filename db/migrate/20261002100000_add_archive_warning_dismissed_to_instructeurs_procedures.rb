# frozen_string_literal: true

class AddArchiveWarningDismissedToInstructeursProcedures < ActiveRecord::Migration[8.1]
  def change
    add_column :instructeurs_procedures, :archive_warning_dismissed, :boolean, default: false, null: false
  end
end
