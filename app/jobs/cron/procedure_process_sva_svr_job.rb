# frozen_string_literal: true

class Cron::ProcedureProcessSVASVRJob < Cron::CronJob
  self.schedule_expression = "every day at 01:15"

  def perform
    Procedure.sva_svr.find_each do |procedure|
      procedure.sva_svr_pending_dossiers.find_each do |dossier|
        ProcedureSVASVRProcessDossierJob.perform_later(dossier)
      end
    end
  end
end
