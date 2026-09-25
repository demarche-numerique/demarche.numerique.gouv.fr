# frozen_string_literal: true

describe Webhooks::EmitEventService do
  let(:procedure) { procedures.individual }
  let(:dossier) { dossiers.en_construction }
  let(:webhook) { webhooks.default }

  before { Flipper.enable(:webhooks_api, procedure) }

  def emit(event_type = :dossier_depose)
    described_class.call(dossier:, event_type:)
  end

  it 'creates an event and enqueues a delivery for subscribed webhooks' do
    webhook

    expect { emit }.to change { procedure.webhook_events.count }.by(1)
      .and have_enqueued_job(Webhooks::DeliveryJob).with(webhook.id)

    event = procedure.webhook_events.last
    expect(event.dossier_id).to eq(dossier.id)
    expect(event.event_type).to eq("dossier_depose")
  end

  it 'does nothing when the feature is disabled' do
    Flipper.disable(:webhooks_api, procedure)

    expect { emit }.not_to change { procedure.webhook_events.count }
  end

  it 'does nothing when no webhook is subscribed to the event type' do
    expect { emit(:message_cree) }.not_to change { procedure.webhook_events.count }
  end

  it 'creates the event but no delivery when the webhook is disabled' do
    webhook.update!(enabled: false)

    expect { emit }.to change { procedure.webhook_events.count }.by(1)
    expect(Webhooks::DeliveryJob).not_to have_been_enqueued.with(webhook.id)
  end

  it 'does nothing when the procedure has been discarded' do
    webhook
    allow(dossier).to receive(:procedure).and_return(nil)

    expect { emit }.not_to change { procedure.webhook_events.count }
  end

  it 'reports and swallows unexpected errors' do
    webhook
    allow(WebhookEvent).to receive(:create!).and_raise("boom")
    expect(Sentry).to receive(:capture_exception)

    expect { emit }.not_to raise_error
  end
end
