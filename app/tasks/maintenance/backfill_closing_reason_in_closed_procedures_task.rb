# frozen_string_literal: true

module Maintenance
  class BackfillClosingReasonInClosedProceduresTask < MaintenanceTasks::Task
    # Remet les messages de cloture d’une démarche proprement (sinon affichage KO).
    # Suite de UpdateClosingReasonIfNoReplacedByIdTask
    # 2024-05-27-01 PR #9930
    def collection
      Procedure
        .with_discarded
        .where(aasm_state: :close)
    end

    def process(procedure)
      if procedure.replaced_by_procedure_id.present?
        procedure.update!(closing_reason: Procedure.closing_reasons.fetch(:internal_procedure))
      else
        procedure.update!(closing_reason: Procedure.closing_reasons.fetch(:other))
      end
    end

    def count
      collection.count
    end
  end
end
