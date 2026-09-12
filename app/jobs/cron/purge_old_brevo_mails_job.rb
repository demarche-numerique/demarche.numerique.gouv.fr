# frozen_string_literal: true

class Cron::PurgeOldBrevoMailsJob < Cron::CronJob
  self.schedule_expression = "every day at 00:15"

  # Deletes one specific day: a lost run is never caught up, keep the full retry budget.
  use_sidekiq_retry

  def perform
    brevo = Brevo::API.new
    day_to_delete = (Time.zone.today - 31.days).strftime("%Y-%m-%d")
    brevo.delete_events(day_to_delete)
  end
end
