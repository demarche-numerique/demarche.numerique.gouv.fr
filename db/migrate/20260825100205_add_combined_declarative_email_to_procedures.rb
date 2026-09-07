# frozen_string_literal: true

class AddCombinedDeclarativeEmailToProcedures < ActiveRecord::Migration[8.1]
  def change
    add_column :procedures, :combined_declarative_email, :boolean, default: true, null: false
  end
end
