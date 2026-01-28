# frozen_string_literal: true

module Maintenance
  class T20260128desarchiveNotTermineDossiersTask < MaintenanceTasks::Task
    # Documentation: cette tâche modifie les données pour désarchiver les dossiers
    # non terminés

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    # run_on_first_deploy

    def collection
      Dossier.where(archived: true, state: ["en_construction", "en_instruction"])
    end

    def process(dossier)
      dossier.update_columns(archived: false, archived_at: nil, archived_by: nil)
    end
  end
end
