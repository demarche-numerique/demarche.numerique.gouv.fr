# frozen_string_literal: true

# The nightly expiration of termine dossiers (Expired::DossiersDeletionService)
# selects on expired_at (dossiers close to expiration, never notified) and on
# termine_close_to_expiration_notice_sent_at (notified more than two weeks ago).
# Neither column was indexed: every one of the dozen statements of a run
# scanned the 8M termine rows, 3 to 36 s each, and the run hit the 60 s
# statement timeout several times a night (#13816).
#
# On a copy of production, the expired_at index brings the close-to-expiration
# selection from 26 s to 2.6 s and the mail eager load from 36 s to 1 s; the
# partial index (2 MB) brings the past-grace selection from 8 s to 0.5 s.
class AddDossiersExpirationIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :dossiers, :expired_at,
              algorithm: :concurrently,
              if_not_exists: true

    add_index :dossiers, :termine_close_to_expiration_notice_sent_at,
              where: "termine_close_to_expiration_notice_sent_at IS NOT NULL",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
