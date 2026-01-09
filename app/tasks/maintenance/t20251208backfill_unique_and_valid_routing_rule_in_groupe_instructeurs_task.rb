# frozen_string_literal: true

module Maintenance
  class T20251208backfillUniqueAndValidRoutingRuleInGroupeInstructeursTask < MaintenanceTasks::Task
    # Documentation: cette tâche modifie les données pour remplir les nouveaux champs booléens
    # `valid_routing_rule` et `unique_routing_rule` de la table `groupe_instructeurs` dans toutes les démarches routées.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # TO DO : uncomment next line for instances after having run on DS production
    run_on_first_deploy

    def collection
      Procedure.where(routing_enabled: true)
    end

    def process(procedure)
      procedure.update_all_groupes_rule_statuses
    end
  end
end
