# frozen_string_literal: true

module Maintenance
  class BackfillEffectifAnnuelAnneeTask < MaintenanceTasks::Task
    # API entreprise: rattrape les informations d’effectif
    # 2024-05-27-01 PR #10053
    def collection
      Etablissement.where.not(entreprise_effectif_annuel: nil).where(entreprise_effectif_annuel_annee: nil)
    end

    def process(etablissement)
      year = etablissement.created_at.year - 1
      procedure = (etablissement.dossier || etablissement.champ&.dossier)&.procedure
      APIEntreprise::EffectifsAnnuelsJob.perform_later(etablissement.id, procedure&.id, year)
    end
  end
end
