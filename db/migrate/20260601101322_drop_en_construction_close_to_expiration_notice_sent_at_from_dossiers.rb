# frozen_string_literal: true

class DropEnConstructionCloseToExpirationNoticeSentAtFromDossiers < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :dossiers, :en_construction_close_to_expiration_notice_sent_at, :datetime, precision: nil
    end
  end
end
