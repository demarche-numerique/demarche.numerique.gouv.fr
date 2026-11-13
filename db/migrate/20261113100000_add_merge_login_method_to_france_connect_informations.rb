# frozen_string_literal: true

class AddMergeLoginMethodToFranceConnectInformations < ActiveRecord::Migration[8.1]
  def change
    add_column :france_connect_informations, :merge_login_method, :string
  end
end
