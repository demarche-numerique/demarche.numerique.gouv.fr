# frozen_string_literal: true

module Maintenance
  class T20260930BackfillTrashedBrouillonRemovalStageTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern

    run_on_first_deploy

    TRASHED = "hidden_by_user_at IS NOT NULL OR hidden_by_expired_at IS NOT NULL"

    # The brouillons whose stage disagrees with their hiding dates: trashed
    # before the hidden stage existed, or trashed or restored by the previous
    # code while the deploy was rolling out. Only those, so a run can be repeated
    # once the previous code is gone.
    def collection
      Dossier.state_brouillon
        .where(removal_stage: nil).where(TRASHED)
        .or(Dossier.state_brouillon.removal_hidden.where.not(TRASHED))
        .in_batches
    end

    # The same stage as DossierRemovalConcern#follow_trash. LEAST skips the NULL
    # hiding date, and the purge date is counted in Paris time, like
    # trash_purge_at, so that it does not move by an hour across a change of
    # daylight saving time.
    def process(batch)
      batch.update_all([<<~SQL.squish, Dossier::REMAINING_WEEKS_BEFORE_DELETION])
        removal_stage = CASE WHEN #{TRASHED} THEN 'hidden' END,
        removal_due_at = CASE WHEN #{TRASHED} THEN
          ((LEAST(hidden_by_user_at, hidden_by_expired_at) AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Paris')
            + make_interval(weeks => ?)) AT TIME ZONE 'Europe/Paris' AT TIME ZONE 'UTC'
        END
      SQL
    end
  end
end
