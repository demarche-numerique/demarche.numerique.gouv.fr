# frozen_string_literal: true

# Re-enqueues webhooks left with pending events (killed worker, lost job).
class Cron::WebhooksDeliverySweeperJob < Cron::CronJob
  self.schedule_expression = "every 5 minutes"

  def perform(*args)
    pending_webhook_ids.each do |webhook_id|
      Webhooks::DeliveryJob.perform_later(webhook_id)
    end
  end

  private

  def pending_webhook_ids
    Webhook
      .deliverable
      .where("delivery_claimed_at IS NULL OR delivery_claimed_at < ?", Webhooks::DeliveryJob::CLAIM_TTL.ago)
      .where("retry_at IS NULL OR retry_at <= ?", Time.current)
      .where(
        # ignores event type floors, pending_events decides below
        WebhookEvent
          .where("webhook_events.procedure_id = webhooks.procedure_id")
          .where("webhook_events.id > webhooks.cursor")
          .where("webhook_events.event_type = ANY(webhooks.event_types)")
          .arel.exists
      )
      .filter { it.pending_events.exists? }
      .map(&:id)
  end
end
