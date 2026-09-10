# frozen_string_literal: true

# Safety net for webhook delivery: re-enqueues webhooks that have pending
# events but no live claim and no scheduled retry (killed worker, lost job,
# event committed just as the previous delivery released its claim).
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
      .where(
        # Coarse prefilter: it ignores event type floors, so a match is not
        # yet proof of pending work — Webhook#pending_events decides below.
        WebhookEvent
          .where("webhook_events.procedure_id = webhooks.procedure_id")
          .where("webhook_events.id > webhooks.cursor")
          .where("webhook_events.event_type = ANY(webhooks.event_types)")
          .arel.exists
      )
      # in_backoff? keeps the backoff formula in one place (a scheduled retry
      # already covers these webhooks); the candidate set is small enough to
      # decide both predicates in Ruby.
      .filter { !it.in_backoff? && it.pending_events.exists? }
      .map(&:id)
  end
end
