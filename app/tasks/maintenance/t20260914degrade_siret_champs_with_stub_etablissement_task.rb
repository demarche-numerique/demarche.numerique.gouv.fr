# frozen_string_literal: true

module Maintenance
  class T20260914degradeSiretChampsWithStubEtablissementTask < MaintenanceTasks::Task
    # An API Entreprise outage used to leave the champ with a stub etablissement,
    # in external_error, or in fetched for the legacy champs that
    # T20251029backfillChampSiretExternalStateTask moved along with the others.
    # Nothing repairs those any more, and their dossier reads as degraded
    # forever: it can never be accepted. Send them where the cron can complete
    # them.

    include RunnableOnDeployConcern

    run_on_first_deploy

    # Taken from the etablissements: the stubs are rare, and the same scan over
    # champs, a far larger table, times out.
    def collection
      Etablissement
        .where(adresse: nil)
        .joins(:champ_data)
        .merge(Champs::SiretChamp.where(external_state: ['fetched', 'external_error']))
    end

    def process(etablissement)
      champ = etablissement.champ_data

      # Some champs never got their external_id backfilled; the stub carries
      # the siret the user typed, and dropping it would lose it for good.
      siret = champ.siret.presence || etablissement.siret
      return if siret.blank?

      # Destroying the stub touches the champ, which dates the dossier: a
      # backfill must not move dossiers up the instructeur list.
      Dossier.no_touching do
        champ.update_columns(etablissement_id: nil, external_id: siret, value: siret, external_state: 'degraded')
        etablissement.destroy
      end
    end

    def count
      # the champs table is large, a COUNT triggers a PG statement timeout
    end
  end
end
