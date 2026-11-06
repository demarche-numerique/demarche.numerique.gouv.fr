# frozen_string_literal: true

# The API v2 connections reach a démarche's dossiers through
# `groupe_instructeur_id` (Dossier.for_procedure). Two request shapes still had
# no index aligned with both their filter and their ordering:
#   - dossiers(state:) ordered by (depose_at, id) or (updated_at, id): the planner
#     took index_dossiers_on_groupe_instructeur_id_and_state_and_archived and
#     read every dossier of the groupe in that state before sorting.
#   - pendingDeletedDossiers: hidden_by_administration_at and hidden_by_user_at
#     had no index, so every request read every dossier of the démarche.
# The hidden_by_* indexes are partial on the non-null rows (a few hundred
# thousand platform-wide), which also serves the `deletedSince` bound.
class AddDossiersConnectionFilterIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  VISIBLE_BY_ADMINISTRATION = "hidden_by_administration_at IS NULL AND hidden_by_expired_at IS NULL"

  def change
    # Strong Migrations flags a fourth column as rarely useful. Here it is the
    # keyset tiebreak: the connections order by (depose_at, id) and paginate
    # with a row comparison on the same pair, so both columns must be in the
    # index for the cursor to stay an index condition. Same shape as
    # index_dossiers_on_groupe_instructeur_id_and_depose_at_and_id.
    safety_assured do
      add_index :dossiers, [:groupe_instructeur_id, :state, :depose_at, :id],
                name: "index_dossiers_on_groupe_and_state_and_depose_at_and_id",
                where: VISIBLE_BY_ADMINISTRATION,
                algorithm: :concurrently,
                if_not_exists: true

      add_index :dossiers, [:groupe_instructeur_id, :state, :updated_at, :id],
                name: "index_dossiers_on_groupe_and_state_and_updated_at_and_id",
                where: VISIBLE_BY_ADMINISTRATION,
                algorithm: :concurrently,
                if_not_exists: true
    end

    add_index :dossiers, :hidden_by_administration_at,
              where: "hidden_by_administration_at IS NOT NULL",
              algorithm: :concurrently,
              if_not_exists: true

    add_index :dossiers, :hidden_by_user_at,
              where: "hidden_by_user_at IS NOT NULL",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
