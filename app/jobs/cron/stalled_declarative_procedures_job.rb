# frozen_string_literal: true

class Cron::StalledDeclarativeProceduresJob < Cron::CronJob
  self.schedule_expression = "every 10 minutes"

  def perform
    recent_or_open = Procedure.where(aasm_state: [:publiee, :depubliee])
      .or(Procedure.where(closed_at: 24.hours.ago..))

    Dossier.state_en_construction
      .where(declarative_triggered_at: nil)
      .joins(:procedure).merge(Procedure.declarative.merge(recent_or_open))
      .find_each { ProcessStalledDeclarativeDossierJob.perform_later(it) }
  end
end
