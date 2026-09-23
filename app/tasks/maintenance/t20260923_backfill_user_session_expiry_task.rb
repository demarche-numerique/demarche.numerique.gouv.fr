# frozen_string_literal: true

module Maintenance
  class T20260923BackfillUserSessionExpiryTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern

    run_on_first_deploy

    # Rows written before roles had deadlines carry none, and `usable` reads a
    # nil deadline as forever. By batch rather than by row: reading a deadline
    # costs the account's roles, and one account answers for all its sessions.
    def collection = UserSession.where(expires_at: nil).in_batches

    # From `created_at`, not from now: a deadline that restarts at the backfill
    # is not the deadline. A row whose account is gone is left alone -- the
    # cascade will take it.
    def process(batch)
      rows = batch.includes(:sessionable).to_a
      preload_gestionnaires(rows)

      rows.group_by { it.sessionable&.session_max_lifetime }.each do |lifetime, same_deadline|
        next if lifetime.nil?

        UserSession.where(id: same_deadline.map(&:id)).expire_from_created_at!(lifetime)
      end
    end

    private

    # The one role User does not eager load, so `session_max_lifetime` would ask
    # for it once per account. Asked once for the whole batch instead.
    def preload_gestionnaires(rows)
      users = rows.map(&:sessionable).grep(User).uniq

      ActiveRecord::Associations::Preloader.new(records: users, associations: :gestionnaire).call
    end
  end
end
