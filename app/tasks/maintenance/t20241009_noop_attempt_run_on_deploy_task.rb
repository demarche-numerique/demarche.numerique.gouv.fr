# frozen_string_literal: true

module Maintenance
  class T20241009NoopAttemptRunOnDeployTask < MaintenanceTasks::Task
    # Documentation: cette tâche ne fait rien mais sert à vérifier
    # qu’elle sera bien exécutée sur le déploiement suivant
    # pour remplacer after party.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    run_on_first_deploy

    def collection
      1.upto(10).to_a
    end

    def process(element)
      # NOOP
    end

    def count
      10
    end
  end
end
