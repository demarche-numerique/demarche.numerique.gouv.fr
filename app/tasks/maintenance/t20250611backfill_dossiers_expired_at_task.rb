# frozen_string_literal: true

module Maintenance
  class T20250611backfillDossiersExpiredAtTask < MaintenanceTasks::Task
    # Documentation: cette tâche modifie les données pour corriger
    # la valeur du champ expired_at des dossiers pour lesquels
    # une notification d’expiration a été envoyée.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    def collection
      Dossier.where.not(state: Dossier.states.fetch(:en_instruction))
    end

    def process(dossier)
      dossier.update_column(:expired_at, dossier.expiration_date)
    end
  end
end
