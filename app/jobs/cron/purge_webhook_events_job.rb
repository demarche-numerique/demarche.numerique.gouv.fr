# frozen_string_literal: true

class Cron::PurgeWebhookEventsJob < Cron::CronJob
  self.schedule_expression = "every day at 3:00"

  def perform(*args)
    WebhookEvent.retention_expired.in_batches.delete_all
  end
end
