# frozen_string_literal: true

module Maintenance
  class T20251029backfillChampSiretExternalStateTask < MaintenanceTasks::Task
    # Documentation: cette tâche modifie les champs siret pour re-aligner la donnée external_state/external_id
    # des champs siret qui ont déjà un établissement rattaché mais qui ont été remplis via l’ancien contrôleur Siret
    # (avant la refonte via ChampExternalDataConcern)

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    run_on_first_deploy

    def collection
      Champs::SiretChamp.in_batches
    end

    def process(batch)
      Champs::SiretChamp
        .where(id: batch.pluck(:id), external_state: 'idle')
        .where.not(etablissement_id: nil)
        .update_all(external_state: 'fetched', external_id: Arel.sql('champs.value'))
    end

    def count
      # noop
    end
  end
end
