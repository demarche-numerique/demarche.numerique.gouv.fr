# frozen_string_literal: true

class ChangeProConnectRestrictionDefaultToInstructeurs < ActiveRecord::Migration[7.2]
  def change
    change_column_default :procedures, :pro_connect_restriction, from: "none", to: "instructeurs"
  end
end
