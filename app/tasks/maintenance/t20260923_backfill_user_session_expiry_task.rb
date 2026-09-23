# frozen_string_literal: true

module Maintenance
  class T20260923BackfillUserSessionExpiryTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern

    run_on_first_deploy

    # Rows written before roles had deadlines carry none, and `usable` reads a
    # nil deadline as forever. The set is closed: every row opened since carries
    # one, so this runs once and is done.
    def collection = UserSession.where(expires_at: nil)

    # From `created_at`, not from now: a deadline that restarts at the backfill
    # is not the deadline. A row whose account is gone is left alone -- the
    # cascade will take it.
    def process(user_session)
      lifetime = user_session.sessionable&.session_max_lifetime
      return if lifetime.nil?

      user_session.update_column(:expires_at, user_session.created_at + lifetime)
    end
  end
end
