# frozen_string_literal: true

module Maintenance
  # Documentation: les démarches existantes exportent leurs colonnes dans
  # l’ordre d’avant l’arbre agrégé (legacy_export_order). Cette tâche le retire
  # à celles pour qui il est le même que l’ordre du formulaire : leurs exports
  # suivront le formulaire, sans que rien ne bouge aujourd’hui.
  class T20261111clearLegacyExportOrderTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern

    run_on_first_deploy

    def collection
      Procedure.with_discarded.where(legacy_export_order: true)
    end

    def process(procedure)
      procedure.update_column(:legacy_export_order, false) if !procedure.legacy_export_order_differs?
    end
  end
end
