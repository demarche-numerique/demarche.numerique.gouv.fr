# frozen_string_literal: true

describe Cron::PurgeWebhookEventsJob, type: :job do
  let(:procedure) { procedures.individual }

  it 'deletes only events past the retention period' do
    old_event = WebhookEvent.create!(procedure:, dossier_id: 1, event_type: "dossier_depose", created_at: (WebhookEvent::RETENTION_PERIOD + 1.day).ago)
    fresh_event = WebhookEvent.create!(procedure:, dossier_id: 1, event_type: "dossier_depose")

    described_class.perform_now

    expect(WebhookEvent.exists?(old_event.id)).to be(false)
    expect(WebhookEvent.exists?(fresh_event.id)).to be(true)
  end
end
