# frozen_string_literal: true

class AddSubmittedWithFranceConnectToDossiers < ActiveRecord::Migration[7.2]
  def change
    add_column :dossiers, :submitted_with_france_connect, :boolean, default: false, null: false
  end
end
