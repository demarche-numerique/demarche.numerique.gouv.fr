# frozen_string_literal: true

module Maintenance
  class T20250318FixIndividualGenderTask < MaintenanceTasks::Task
    # Documentation: cette tâche corrige la valeur du gender dans la table
    # Individual, notamment dans les cas où l’utilisateur a fait traduire la
    # page par son navigateur.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    # run_on_first_deploy

    GENDER = {
      "Mr." => 'M.',
      "Господин." => 'M.',
      "السيد." => 'M.',
      "Г-жо." => 'Mme',
      "Bayan." => 'Mme',
      "Госпожа." => 'Mme',
      "Sra." => 'Mme',
      "السيدة." => 'Mme',
      "م." => 'M.',
      "Mrs." => 'Mme',
    }

    def collection
      Individual.where.not(gender: ['M.', 'Mme'])
    end

    def process(element)
      element.update!(gender: GENDER.fetch(element.gender, 'Mme'))
    end

    def count
      collection.count
    end
  end
end
