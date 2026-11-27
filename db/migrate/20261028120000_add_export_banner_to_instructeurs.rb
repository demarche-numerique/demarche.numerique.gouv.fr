# frozen_string_literal: true

class AddExportBannerToInstructeurs < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      add_column :instructeurs, :export_banner_dismissed_at, :datetime, default: -> { "(now() AT TIME ZONE 'UTC')" }
    end
  end
end
