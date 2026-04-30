# frozen_string_literal: true

module Maintenance
  class SpreadDossierDeletionTask < MaintenanceTasks::Task
    # Contourne un égorgement de suppression de millions de dossiers qui aurait eu lieu le même jour
    # 2024-05-27-01 PR #10062
    ERROR_OCCURED_AT = Date.new(2024, 2, 14)
    ERROR_OCCURED_RANGE = ERROR_OCCURED_AT.at_midnight...(ERROR_OCCURED_AT + 1.day)
    SPREAD_DURATION_IN_DAYS = 150

    def collection
      Dossier.where(termine_close_to_expiration_notice_sent_at: ERROR_OCCURED_RANGE)
        .in_batches
    end

    def process(element)
      element.update_all(termine_close_to_expiration_notice_sent_at: ERROR_OCCURED_AT + random_date_spread.days)
    end

    # since we do not keep track of current batch idx,
    # delay termine_close_to_expiration_notice_sent_at using random approach
    # should be good enough
    def random_date_spread
      rand(1..SPREAD_DURATION_IN_DAYS)
    end
  end
end
