# frozen_string_literal: true

class AddAPIEntrepriseTokenExpirationNoticeSentAtToProcedures < ActiveRecord::Migration[7.2]
  def change
    add_column :procedures, :api_entreprise_token_expiration_notice_sent_at, :datetime
  end
end
