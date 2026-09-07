# frozen_string_literal: true

# TODO: remove this job in a few days once all failed etablissements are queued as separate jobs
class Cron::BackfillSiretDegradedModeJob < Cron::CronJob
  self.schedule_expression = "every 2 hour"

  def perform(*args)
    fix_etablissement_with_dossier
  end

  def fix_etablissement_with_dossier
    Etablissement.joins(:dossier).where(adresse: nil).find_each do |etablissement|
      begin
        procedure_id = etablissement.dossier.procedure.id

        APIEntrepriseService.update_etablissement_from_degraded_mode(etablissement, procedure_id)
      rescue => e
        Sentry.capture_exception(e)
      end
    end
  end
end
