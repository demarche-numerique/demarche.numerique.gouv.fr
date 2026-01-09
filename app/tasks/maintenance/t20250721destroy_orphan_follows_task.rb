# frozen_string_literal: true

module Maintenance
  class T20250721destroyOrphanFollowsTask < MaintenanceTasks::Task
    # Documentation: cette tâche vient supprimer les follows orphelins dûs
    # à la suppression d’un dossier ou d’un instructeur

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    # run_on_first_deploy

    def collection
      Follow
        .left_joins(:instructeur, :dossier)
        .where('instructeurs.id IS NULL OR dossiers.id IS NULL')
        .in_batches
    end

    def process(batch_of_follows)
      batch_of_follows.delete_all
    end

    def count
      with_statement_timeout("5min") do
        Follow
          .left_joins(:instructeur, :dossier)
          .where('instructeurs.id IS NULL OR dossiers.id IS NULL').count(:id) / 1000
      end
    end
  end
end
