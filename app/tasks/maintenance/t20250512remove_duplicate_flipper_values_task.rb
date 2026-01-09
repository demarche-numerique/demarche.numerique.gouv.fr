# frozen_string_literal: true

module Maintenance
  class T20250512removeDuplicateFlipperValuesTask < MaintenanceTasks::Task
    # Cette tache suit T20250512prepareUnifyFlipperValuesTask
    # elle supprime l’ancien format de valeur de Flipper maintenant
    # que le code a été migré.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    run_on_first_deploy

    def collection
      Flipper::Adapters::ActiveRecord::Gate.all
    end

    def process(flipper_gate)
      if flipper_gate.value != flipper_gate.value.sub(':', ';')
        flipper_gate.destroy
      end
    end
  end
end
