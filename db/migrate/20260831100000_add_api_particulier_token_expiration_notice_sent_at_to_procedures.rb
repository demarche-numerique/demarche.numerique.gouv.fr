# frozen_string_literal: true

class AddAPIParticulierTokenExpirationNoticeSentAtToProcedures < ActiveRecord::Migration[8.1]
  def change
    add_column :procedures, :api_particulier_token_expiration_notice_sent_at, :datetime
  end
end
