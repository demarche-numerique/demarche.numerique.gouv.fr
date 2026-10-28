# frozen_string_literal: true

class AddExportBannerToInstructeurs < ActiveRecord::Migration[8.1]
  def change
    add_column :instructeurs, :last_requested_export_id, :bigint
    add_column :instructeurs, :last_requested_export_dismissed_at, :datetime
    add_column :instructeurs, :colleague_exports_dismissed_at, :datetime
  end
end
