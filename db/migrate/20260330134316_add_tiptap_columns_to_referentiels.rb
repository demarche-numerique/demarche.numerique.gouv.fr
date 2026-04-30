# frozen_string_literal: true

class AddTiptapColumnsToReferentiels < ActiveRecord::Migration[7.2]
  def change
    add_column :referentiels, :url_tiptap, :jsonb
    add_column :referentiels, :test_data_tiptap, :jsonb
    add_column :referentiels, :use_tiptap, :boolean, default: true, null: false
    Referentiel.update_all(use_tiptap: false)
  end
end
