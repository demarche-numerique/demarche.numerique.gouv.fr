# frozen_string_literal: true

module Maintenance
  class T20261001BackfillWarnedBrouillonRemovalStageTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern

    run_on_first_deploy

    NOTICED = "brouillon_close_to_expiration_notice_sent_at IS NOT NULL"

    # The brouillons out of the trash whose stage disagrees with their notice:
    # warned before the warned stage existed, or warned, edited or extended by
    # the previous code while the deploy was rolling out. Only those, so a run
    # can be repeated once the previous code is gone.
    def collection
      out_of_trash = Dossier.state_brouillon.where(hidden_by_user_at: nil, hidden_by_expired_at: nil)

      out_of_trash.where(removal_stage: nil).where(NOTICED)
        .or(out_of_trash.removal_warned.where.not(NOTICED))
        .in_batches
    end

    # The same stage as DossierRemovalConcern#follow_removal, the destruction
    # date counted in Paris time like notice_deletion_at, so that it does not
    # move by an hour across a change of daylight saving time.
    def process(batch)
      batch.update_all([<<~SQL.squish, Expired::REMAINING_WEEKS_BEFORE_EXPIRATION])
        removal_stage = CASE WHEN #{NOTICED} THEN 'warned' END,
        removal_due_at = CASE WHEN #{NOTICED} THEN
          ((brouillon_close_to_expiration_notice_sent_at AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Paris')
            + make_interval(weeks => ?)) AT TIME ZONE 'Europe/Paris' AT TIME ZONE 'UTC'
        END
      SQL
    end
  end
end
