# frozen_string_literal: true

module Maintenance
  class T20260616backfillRNAExternalIdTask < MaintenanceTasks::Task
    # Documentation: avant le refacto rna_use_external_champ_concern, le numéro RNA
    # était stocké dans `value`. Le nouveau workflow (validation, fetch, préremplissage
    # du formulaire d'édition) lit et écrit `external_id`. On recopie value -> external_id
    # pour les anciens champs RNA afin qu'ils restent cohérents avec le nouveau code.

    include RunnableOnDeployConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    run_on_first_deploy

    no_collection

    def process
      ChampData
        .where(type: "Champs::RNAChamp")
        .where(external_id: nil)
        .where.not(value: nil)
        .update_all('external_id = value')
    end
  end
end
