# frozen_string_literal: true

module Maintenance
  class BackfillMissingEntrepriseDataTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    def collection
      Etablissement
        .where(created_at: 6.months.ago..)
        .where.not(siret: nil)
        .where(entreprise_siren: nil)
        .left_joins(:dossier, :champ_data)
        .where("dossiers.id IS NOT NULL OR champs.id IS NOT NULL")
        .distinct
    end

    def process(etablissement)
      procedure_id = find_procedure_id(etablissement)
      return if procedure_id.nil?

      # Add delay
      wait_time = rand(0..max_wait)
      APIEntrepriseService.perform_later_fetch_jobs(etablissement, procedure_id, nil, wait: wait_time.seconds)
    rescue StandardError => e
      # Log l'erreur mais continue avec les autres établissements
      Rails.logger.error("BackfillMissingEntrepriseDataTask: Error processing etablissement #{etablissement.id}: #{e.message}")
      Sentry.capture_exception(e, tags: { etablissement: etablissement.id, siret: etablissement.siret })
    end

    private

    def max_wait
      # spread the jobs over 10 seconds * number of etablissements
      @max_wait ||= collection.count * 10
    end

    def find_procedure_id(etablissement)
      d = dossier(etablissement)
      d&.procedure&.id
    end

    def dossier(etablissement)
      etablissement.dossier || etablissement.champ_data&.dossier
    end
  end
end
