# frozen_string_literal: true

class AddAcrToAgentConnectInformations < ActiveRecord::Migration[8.1]
  def change
    add_column :agent_connect_informations, :acr, :string
  end
end
