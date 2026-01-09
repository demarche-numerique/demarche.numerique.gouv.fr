# frozen_string_literal: true

module Maintenance
  class T20251118destroyInstructeursProcedureOfInstructeursRemovedFromProcedureTask < MaintenanceTasks::Task
    # Documentation: cette tâche permet de supprimer les instructeurs_procedure
    # qui correspondent à des instructeurs ne faisant plus partis de la procedure,
    # cad des instructeurs qui ne font plus partis d’aucun groupe de la procédure.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    # run_on_first_deploy

    def collection
      AssignTo
        .joins(:procedure)
        .pluck("procedures.id", "assign_tos.instructeur_id")
        .group_by(&:first)
        .transform_values { |values| values.map(&:last).uniq }
        .to_a
    end

    def process(element)
      procedure_id, instructeur_ids = element

      InstructeursProcedure
        .where(procedure_id:)
        .where.not(instructeur_id: instructeur_ids)
        .delete_all
    end

    def count
      with_statement_timeout("5min") do
        collection.count
      end
    end
  end
end
