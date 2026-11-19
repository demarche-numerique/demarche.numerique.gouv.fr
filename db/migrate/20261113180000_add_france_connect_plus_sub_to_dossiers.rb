# frozen_string_literal: true

class AddFranceConnectPlusSubToDossiers < ActiveRecord::Migration[8.1]
  def change
    add_column :dossiers, :france_connect_plus_sub, :string
  end
end
