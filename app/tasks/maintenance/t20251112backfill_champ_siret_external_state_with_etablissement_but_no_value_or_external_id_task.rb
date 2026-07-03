# frozen_string_literal: true

module Maintenance
  class T20251112backfillChampSiretExternalStateWithEtablissementButNoValueOrExternalIdTask < MaintenanceTasks::Task
    # Documentation: cette tâche modifie les données pour…

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    # run_on_first_deploy

    def collection
      ChampData.where(type: "Champs::SiretChamp")
    end

    def process(champ)
      return if champ.value.present? || champ.external_id.present?
      return if champ.external_state != ChampData.external_states[:fetched]
      return if champ.etablissement.nil?

      champ.update_columns(
        value: champ.etablissement.siret,
        external_id: champ.etablissement.siret
      )
    end

    def count
      # noop
    end
  end
end
