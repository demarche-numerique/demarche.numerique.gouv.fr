# frozen_string_literal: true

describe Cron::WebhooksDeliverySweeperJob, type: :job do
  let(:procedure) { procedures.individual }
  let(:webhook) { webhooks.default }

  subject(:perform) { described_class.perform_now }

  context 'with a pending event past the cursor' do
    before { WebhookEvent.create!(procedure:, dossier_id: 1, event_type: "dossier_depose") }

    it 'enqueues a delivery' do
      webhook

      perform

      expect(Webhooks::DeliveryJob).to have_been_enqueued.with(webhook.id)
    end

    it 'skips webhooks with a fresh claim' do
      webhook.update!(delivery_claimed_at: Time.current)

      perform

      expect(Webhooks::DeliveryJob).not_to have_been_enqueued.with(webhook.id)
    end

    it 'skips webhooks still inside their backoff window' do
      webhook.update!(consecutive_failures: 10, last_attempt_at: 1.minute.ago)

      perform

      expect(Webhooks::DeliveryJob).not_to have_been_enqueued.with(webhook.id)
    end

    it 'enqueues webhooks past their backoff window' do
      webhook.update!(consecutive_failures: 1, last_attempt_at: 1.minute.ago)

      perform

      expect(Webhooks::DeliveryJob).to have_been_enqueued.with(webhook.id)
    end

    it 'skips disabled webhooks' do
      webhook.update!(enabled: false)

      perform

      expect(Webhooks::DeliveryJob).not_to have_been_enqueued.with(webhook.id)
    end

    it 'skips webhooks of a discarded procedure' do
      webhook
      procedure.discard!

      perform

      expect(Webhooks::DeliveryJob).not_to have_been_enqueued.with(webhook.id)
    end
  end

  context 'with matching events only below their event type floor' do
    it 'enqueues nothing' do
      webhook
      WebhookEvent.create!(procedure:, dossier_id: 1, event_type: "message_cree")
      webhook.update!(event_types: ["dossier_depose", "message_cree"])

      perform

      expect(Webhooks::DeliveryJob).not_to have_been_enqueued.with(webhook.id)
    end
  end

  context 'without pending events' do
    it 'enqueues nothing' do
      webhook

      perform

      expect(Webhooks::DeliveryJob).not_to have_been_enqueued.with(webhook.id)
    end
  end
end
