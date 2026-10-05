# frozen_string_literal: true

class DropTagsFromProcedures < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_column :procedures, :tags, :text, array: true, default: []
    end
  end
end
