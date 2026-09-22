# frozen_string_literal: true

# The removal stage (#13915) is written along the legacy columns by events.
# Every morning, once the brouillon crons are done, counts the dossiers
# breaking an invariant of the stage, so that a writer the events miss shows
# up before the stage is trusted, and while it is.
#
# Each invariant is checked on its own, in plain SQL: nothing is shared with
# the code writing the stage, which would agree with itself.
class Cron::BrouillonRemovalReconciliationJob < Cron::CronJob
  include Maintenance::StatementsHelpersConcern

  self.schedule_expression = "every day at 6:30"
  queue_as :low

  # A trashed brouillon is purged two weeks after its earliest hiding.
  HIDING = "LEAST(hidden_by_user_at, hidden_by_expired_at)"
  NOTICE = "brouillon_close_to_expiration_notice_sent_at"

  # `t ± n.weeks` in Ruby moves by calendar days in Paris time: across a DST
  # change it is 14 days ± 1 hour in UTC, where the columns are stored.
  def self.weeks(column, operator, count)
    "((#{column} AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Paris') #{operator} INTERVAL '#{Integer(count)} weeks') AT TIME ZONE 'Europe/Paris' AT TIME ZONE 'UTC'"
  end

  # One column per invariant, counting the dossiers breaking it.
  MANAGED_COUNTS = <<~SQL.squish
    COUNT(*) FILTER (WHERE removal_stage IS NULL) AS without_stage,
    COUNT(*) FILTER (WHERE removal_stage = 'hidden' AND #{HIDING} IS NULL) AS hidden_without_hiding,
    COUNT(*) FILTER (WHERE removal_stage <> 'hidden' AND #{HIDING} IS NOT NULL) AS hiding_without_hidden,
    COUNT(*) FILTER (WHERE removal_stage = 'warned' AND #{NOTICE} IS NULL) AS warned_without_notice,
    COUNT(*) FILTER (WHERE removal_stage = 'retained' AND #{NOTICE} IS NOT NULL) AS notice_without_warned,
    COUNT(*) FILTER (WHERE removal_stage = 'retained' AND (removal_due_at = #{weeks('expired_at', '-', Expired::REMAINING_WEEKS_BEFORE_EXPIRATION)}) IS NOT TRUE) AS retained_due_at,
    COUNT(*) FILTER (WHERE removal_stage = 'warned' AND (removal_due_at = expired_at) IS NOT TRUE) AS warned_due_at,
    COUNT(*) FILTER (WHERE removal_stage = 'hidden' AND #{HIDING} IS NOT NULL AND (removal_due_at = #{weeks(HIDING, '+', Dossier::REMAINING_WEEKS_BEFORE_DELETION)}) IS NOT TRUE) AS hidden_due_at
  SQL

  # The rows a stage owns although their state does not, counted apart: they
  # have no invariant of their own to break.
  UNMANAGED_DRIFT = "removal_stage IS NOT NULL OR removal_due_at IS NOT NULL"

  def perform
    # One read of every managed dossier (0.5 M brouillons scattered over the
    # table, through index_dossiers_on_state).
    counts = with_statement_timeout("10min") { drift_counts }

    if counts.values.any?(&:positive?)
      Sentry.capture_message("Brouillon removal stage out of sync", level: :warning, extra: counts)
    end
  end

  # The dossiers of `scope` breaking an invariant, counted per invariant.
  # Every dossier by default; narrowing the scope down to one procedure keeps
  # the pass cheap enough to run it by hand while a drift is being fixed.
  def drift_counts(scope = Dossier.all)
    managed = scope.where(state: Dossier::REMOVAL_MANAGED_STATES).reselect(MANAGED_COUNTS)

    # Through index_dossiers_removal_stage_unmanaged, empty when in sync: its
    # predicate must follow REMOVAL_MANAGED_STATES.
    unmanaged = scope
      .where.not(state: Dossier::REMOVAL_MANAGED_STATES)
      .where(UNMANAGED_DRIFT)
      .reselect("COUNT(*)")

    Dossier.with_connection do |connection|
      connection.select_one(managed.to_sql, "Removal Drift")
        .symbolize_keys
        .merge(unmanaged_with_stage: connection.select_value(unmanaged.to_sql, "Removal Drift"))
    end
  end
end
