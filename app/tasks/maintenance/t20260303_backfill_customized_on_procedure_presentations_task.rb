# frozen_string_literal: true

module Maintenance
  class T20260303BackfillCustomizedOnProcedurePresentationsTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern

    def collection
      ProcedurePresentation.includes(assign_to: :procedure)
    end

    def process(presentation)
      procedure = presentation.assign_to.procedure

      displayed = presentation.displayed_columns.map(&:h_id)
      default = procedure.default_displayed_columns.map(&:h_id)

      presentation.update_columns(
        customized: sort_h_ids(displayed) != sort_h_ids(default)
      )
    # a column can be not found for various reasons (deleted tdc, changed type, etc)
    # in this case we just ignore the error and continue
    rescue ActiveRecord::RecordNotFound
    end

    private

    def sort_h_ids(array)
      array.sort_by(&:to_s)
    end
  end
end
