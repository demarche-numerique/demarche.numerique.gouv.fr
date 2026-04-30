# frozen_string_literal: true

module Maintenance
  class T20260319migrateOrphanTitreIdentiteChampsTask < MaintenanceTasks::Task
    # Documentation: cette tâche migre les champs orphelins TitreIdentiteChamp
    # vers PieceJustificativeChamp après la suppression du type TitreIdentite.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    # run_on_first_deploy

    no_collection

    def process
      Champ.where(type: "Champs::TitreIdentiteChamp")
        .update_all(type: "Champs::PieceJustificativeChamp")
    end
  end
end
