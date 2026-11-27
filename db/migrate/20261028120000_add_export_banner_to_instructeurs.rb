# frozen_string_literal: true

class AddExportBannerToInstructeurs < ActiveRecord::Migration[8.1]
  def change
    add_column :instructeurs, :export_banner_dismissed_at, :datetime
  end
end
