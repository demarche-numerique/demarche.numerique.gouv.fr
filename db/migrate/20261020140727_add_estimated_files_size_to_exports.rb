# frozen_string_literal: true

class AddEstimatedFilesSizeToExports < ActiveRecord::Migration[8.1]
  def change
    add_column :exports, :estimated_files_size, :bigint
  end
end
