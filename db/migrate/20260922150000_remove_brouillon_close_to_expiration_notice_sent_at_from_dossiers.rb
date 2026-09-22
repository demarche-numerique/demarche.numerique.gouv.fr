# frozen_string_literal: true

# The removal stage (#13915) has been the only record of a brouillon notice
# since the previous release, which also put this column in
# Dossier.ignored_columns: no running process selects it any more, so
# dropping it breaks nothing.
class RemoveBrouillonCloseToExpirationNoticeSentAtFromDossiers < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_column :dossiers, :brouillon_close_to_expiration_notice_sent_at, :datetime, precision: nil
    end
  end
end
