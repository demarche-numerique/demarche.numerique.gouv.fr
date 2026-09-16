# frozen_string_literal: true

class AddAPIEntrepriseTokenRejectedAtToProcedures < ActiveRecord::Migration[8.1]
  def change
    add_column :procedures, :api_entreprise_token_rejected_at, :datetime
  end
end
