# frozen_string_literal: true

class Cron::BackfillSiretDegradedModeJob < Cron::CronJob
  self.schedule_expression = "every 2 hour"

  def perform(*args)
    fix_etablissement_with_dossier
    fix_etablissement_with_champs
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

  def fix_etablissement_with_champs
    Etablissement.joins(:champ_data).where(adresse: nil).find_each do |etablissement|
      begin
        procedure_id = etablissement.champ_data.procedure.id

        APIEntrepriseService.update_etablissement_from_degraded_mode(etablissement, procedure_id)
      rescue => e
        Sentry.capture_exception(e)
      end
    end
  end
end
