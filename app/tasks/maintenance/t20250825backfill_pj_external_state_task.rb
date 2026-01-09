# frozen_string_literal: true

module Maintenance
  class T20250825backfillPjExternalStateTask < MaintenanceTasks::Task
    # Cette tâche convertit les qq champs pj de type RIB au niveau système
    # de machine à état en remplissant la colonne external_state à partir de l’état calculé
    # via les méthodes external_data_fetched? et external_error_present?
    # Cette tache ne devrait concerner que l’instance DINUM, la feature RIB étant encore
    # sous feature flag.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    # run_on_first_deploy
    #
    attribute :procedure_ids, :string
    validates :procedure_ids, presence: true

    def collection
      Procedure
        .where(id: procedure_ids.split(",").map(&:strip)).flat_map(&:dossiers)
    end

    def process(dossier)
      pjs = dossier.project_champs_public
        .filter { it.type == "Champs::PieceJustificativeChamp" && it.RIB? == true }

      pjs.filter(&:idle?).each do |pj|
        # ! the old method external_data_fetched? is now removed
        # run the task before applying this version
        #
        # if pj.external_data_fetched?
        #   pj.external_data_fetched!
        # elsif pj.external_error_present?
        #   pj.external_data_error!
        # end
      end
    end

    def count
      # Optionally, define the number of rows that will be iterated over
      # This is used to track the task's progress
    end
  end
end
