# frozen_string_literal: true

module Maintenance
  class T20260731cleanServiceSiretTask < MaintenanceTasks::Task
    # Documentation: cette tâche nettoie l'ancien SIRET de test des services,
    # correspondant à un vrai SIRET (La Poste) : 35600082800018.
    #
    # Pour ces services :
    # - si le service est associé à au moins une procédure publiée ou close,
    #   son SIRET est remis à nil ;
    # - si le service n'est associé qu'à des procédures en brouillon,
    #   son SIRET devient le nouveau SIRET de test : 00000000000000.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    # run_on_first_deploy

    def collection
      Service.includes(:procedures).where(siret: '35600082800018')
    end

    def process(service)
      siret = service.procedures.publiees_ou_closes.exists? ? nil : Service::SIRET_TEST

      service.update_columns(siret:)
    end

    def count
      collection.count
    end
  end
end
