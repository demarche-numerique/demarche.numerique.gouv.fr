# frozen_string_literal: true

module Maintenance
  class ComputeChampMatchesTask < MaintenanceTasks::Task
    def collection
      ProcedureUserOverlap.champs_pending
    end

    def process(overlap)
      overlap.refresh_champ_matches!
    end
  end
end
