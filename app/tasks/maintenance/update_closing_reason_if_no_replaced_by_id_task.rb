# frozen_string_literal: true

module Maintenance
  class UpdateClosingReasonIfNoReplacedByIdTask < MaintenanceTasks::Task
    # Remet les messages de cloture d’une démarche proprement (sinon affichage KO).
    # Avant BackfillClosingReasonInClosedProceduresTask
    # 2024-03-21-01 PR #10158
    def collection
      Procedure
        .with_discarded
        .closes
        .where(closing_reason: Procedure.closing_reasons.fetch(:internal_procedure))
        .where(replaced_by_procedure_id: nil)
    end

    def process(procedure)
      procedure.closing_reason_other!
    end
  end
end
