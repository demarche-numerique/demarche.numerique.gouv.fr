# frozen_string_literal: true

module Maintenance
  class T20260907migrateDegradedSiretChampsTask < MaintenanceTasks::Task
    # Champs left in external_error by an API Entreprise outage carry a stub
    # etablissement. They are degraded champs in the new model: move them, so
    # Cron::RetryDegradedSiretChampJob can complete them.

    include RunnableOnDeployConcern

    run_on_first_deploy

    def collection
      Champs::SiretChamp.where(external_state: 'external_error').where.not(etablissement_id: nil).includes(:etablissement)
    end

    def process(champ)
      etablissement = champ.etablissement
      return if etablissement.nil? || !etablissement.as_degraded_mode?

      # Some champs never got their external_id backfilled; the stub carries
      # the siret the user typed, and dropping it would lose it for good.
      siret = champ.siret.presence || etablissement.siret
      return if siret.blank?

      champ.update_columns(etablissement_id: nil, external_id: siret, value: siret, external_state: 'degraded')
      etablissement.destroy
    end

    def count
      # the champs table is large, a COUNT triggers a PG statement timeout
    end
  end
end
