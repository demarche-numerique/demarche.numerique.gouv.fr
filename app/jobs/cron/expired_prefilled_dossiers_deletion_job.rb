# frozen_string_literal: true

class Cron::ExpiredPrefilledDossiersDeletionJob < Cron::CronJob
  self.schedule_expression = Expired.schedule_at(self)

  def perform
    Dossier.prefilled.state_brouillon.where(user_id: nil, updated_at: ..Expired::DAYS_BEFORE_UNCLAIMED_PREFILLED_EXPIRATION.days.ago).destroy_all
  end
end
