# frozen_string_literal: true

module Maintenance
  class T20260922backfillBrouillonRemovalStageTask < MaintenanceTasks::Task
    # Gives a removal stage (#13915) to the brouillons created before the
    # stage was written: every brouillon created since enters it on creation.
    # Run it by hand, then wait for Cron::BrouillonRemovalReconciliationJob to
    # report no drift before enabling the brouillon_removal_stage flag.
    #
    # The stage and its due date are derived from the legacy columns in the
    # UPDATE itself, first match wins:
    #   hidden_by_user_at or hidden_by_expired_at → hidden, due at the
    #     earliest one + 2 weeks (when the purge cron takes it);
    #   the brouillon notice → warned, due at the notice + 2 weeks;
    #   otherwise → retained, due at expired_at − 2 weeks (the notice date).
    # The SQL is frozen here on purpose: the task is one-shot and the rule is
    # the one of the legacy columns when it was written. It goes away with
    # the notice column (PR 8 of #13915).
    #
    # 0.5 M brouillons among 11.5 M dossiers: batching the brouillon filter
    # walks the primary key through ~20 dossiers for each brouillon until a
    # batch fills (#13816, #13895). The task walks fixed ranges of ids
    # instead, from 0 so that a resumed run gets the same ranges: one bounded
    # primary key scan per UPDATE.
    #
    # resync: a request which loaded a brouillon just before its range was
    # adopted still sees it without a stage, so it writes the legacy columns
    # only (an autosave moves expired_at, a trash sets hidden_by_user_at) and
    # the stage it just got goes stale. The events only move a dossier whose
    # stage they know. With resync, the task also re-derives every brouillon
    # whose stage or due date differs from its legacy columns, and clears the
    # stage left on other dossiers: run it again that way when the
    # reconciliation reports a drift, while the flag is still off.

    RANGE_SIZE = 10_000

    attribute :resync, :boolean, default: false

    # `t ± 2.weeks` in Ruby moves by calendar days in Paris time: across a DST
    # change it is 14 days ± 1 hour in UTC, where the columns are stored.
    def self.two_weeks(column, operator)
      "((#{column} AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Paris') #{operator} INTERVAL '2 weeks') AT TIME ZONE 'Europe/Paris' AT TIME ZONE 'UTC'"
    end
    private_class_method :two_weeks

    STAGE = <<~SQL.squish.freeze
      CASE
        WHEN hidden_by_user_at IS NOT NULL OR hidden_by_expired_at IS NOT NULL THEN 'hidden'
        WHEN brouillon_close_to_expiration_notice_sent_at IS NOT NULL THEN 'warned'
        ELSE 'retained'
      END
    SQL

    DUE_AT = <<~SQL.squish.freeze
      CASE
        WHEN hidden_by_user_at IS NOT NULL OR hidden_by_expired_at IS NOT NULL
          THEN #{two_weeks('LEAST(hidden_by_user_at, hidden_by_expired_at)', '+')}
        WHEN brouillon_close_to_expiration_notice_sent_at IS NOT NULL
          THEN #{two_weeks('brouillon_close_to_expiration_notice_sent_at', '+')}
        ELSE #{two_weeks('expired_at', '-')}
      END
    SQL

    def collection
      last_id = Dossier.maximum(:id)
      return [] if last_id.nil?

      (0..last_id).step(RANGE_SIZE).to_a
    end

    def process(from)
      range = { from:, to: from + RANGE_SIZE }

      rows = Dossier.with_connection do |connection|
        # The state and stage are checked again on the row being written: a
        # brouillon submitted, or given a stage, in the meantime is left alone.
        connection.select_rows(Dossier.sanitize_sql_array([<<~SQL.squish, range]), "Backfill Brouillon Removal Stage")
          UPDATE dossiers SET removal_stage = #{STAGE}, removal_due_at = #{DUE_AT}
          WHERE id >= :from AND id < :to AND state = 'brouillon'
            AND (removal_stage IS NULL #{"OR (removal_stage, removal_due_at) IS DISTINCT FROM (#{STAGE}, #{DUE_AT})" if resync})
          RETURNING id, removal_stage = 'retained' AND expired_at IS NULL
        SQL
      end

      clear_unmanaged(range) if resync

      # A retained brouillon without expired_at (never saved since the column
      # exists) has no due date yet: computed as a save does.
      without_expired_at = rows.filter_map { |id, missing| id if missing }
      Dossier.where(id: without_expired_at).includes(:procedure).find_each(&:update_expired_at)
    end

    private

    def clear_unmanaged(range)
      Dossier.where(id: range[:from]...range[:to])
        .where("state <> 'brouillon' AND (removal_stage IS NOT NULL OR removal_due_at IS NOT NULL)")
        .update_all(removal_stage: nil, removal_due_at: nil)
    end
  end
end
