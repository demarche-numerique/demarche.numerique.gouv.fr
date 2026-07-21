# frozen_string_literal: true

class AddIdentityKindToDemarches < ActiveRecord::Migration[7.2]
  def change
    add_column :procedures, :identity_kind, :string, null: true
  end
end
