# frozen_string_literal: true

module Maintenance
  class ComputeProcedureUserOverlapsTask < MaintenanceTasks::Task
    no_collection

    def process
      ProcedureUserOverlap.refresh_within(Procedure.champ_matching_enabled.ids)
    end
  end
end
