# frozen_string_literal: true

module Maintenance
  class T20250206destroyContactInformationsInNotRoutedProceduresTask < MaintenanceTasks::Task
    # Documentation: cette tâche modifie les données pour supprimer les informations de contact des démarches non routées. La fonctionnalité d’informations de contact avait été ouverte par erreur aux démarches non routées.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    def collection
      groupes_with_contact_info_ids = ContactInformation.pluck(:groupe_instructeur_id)

      GroupeInstructeur
        .where(id: groupes_with_contact_info_ids)
        .filter { !_1.procedure.routing_enabled? }
    end

    def process(groupe)
      groupe.contact_information.destroy
    end
  end
end
