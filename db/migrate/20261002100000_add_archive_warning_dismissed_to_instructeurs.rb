# frozen_string_literal: true

class AddArchiveWarningDismissedToInstructeurs < ActiveRecord::Migration[8.1]
  def change
    add_column :instructeurs, :archive_warning_dismissed, :boolean, default: false, null: false
  end
end
