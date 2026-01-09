# frozen_string_literal: true

module Maintenance
  class T20250320FixInstructeursProceduresWithoutPositionTask < MaintenanceTasks::Task
    # Documentation: backfill l’attribut `position` d'InstructeurProcedure qui ont été créés avec une valeur nil

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    run_on_first_deploy

    def collection
      InstructeursProcedure.where(position: nil)
    end

    def process(element)
      element.update(position: 99)
    end
  end
end
