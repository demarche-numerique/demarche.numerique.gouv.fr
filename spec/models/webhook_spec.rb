# frozen_string_literal: true

describe Webhook, type: :model do
  let(:procedure) { procedures.individual }

  describe 'secret' do
    it 'is generated on create and can be regenerated' do
      webhook = procedure.webhooks.create!(url: "https://example.com/hook", event_types: ["dossier_depose"])
      original_secret = webhook.secret

      expect(original_secret).to be_present

      webhook.regenerate_secret
      expect(webhook.secret).not_to eq(original_secret)
    end
  end

  describe 'validations' do
    subject(:webhook) { described_class.new(procedure:, url:, event_types:) }

    let(:url) { "https://example.com/hook" }
    let(:event_types) { ["dossier_depose"] }

    it { expect(webhook).to be_valid }

    context 'with a local url' do
      let(:url) { "http://localhost/hook" }

      it { expect(webhook).not_to be_valid }
    end

    context 'with a private ip url' do
      let(:url) { "https://192.168.1.1/hook" }

      it { expect(webhook).not_to be_valid }
    end

    context 'without event types' do
      let(:event_types) { [] }

      it { expect(webhook).not_to be_valid }
    end

    context 'with an unknown event type' do
      let(:event_types) { ["dossier_depose", "unknown_event"] }

      it { expect(webhook).not_to be_valid }
    end

    context 'when the procedure reached the webhooks limit' do
      before do
        rows = Array.new(Webhook::MAX_PER_PROCEDURE) do |i|
          { procedure_id: procedure.id, url: "https://example.com/#{i}", secret: "secret", event_types: '{dossier_depose}', created_at: Time.current, updated_at: Time.current }
        end
        Webhook.insert_all(rows)
      end

      it { expect(webhook).not_to be_valid }
    end
  end

  describe 'cursor initialization' do
    it 'starts after the latest event of the procedure' do
      event = WebhookEvent.create!(procedure:, dossier_id: 1, event_type: "dossier_depose")
      webhook = procedure.webhooks.create!(url: "https://example.com/hook", event_types: ["dossier_depose"])

      expect(webhook.cursor).to eq(event.id)
    end
  end

  describe '#deliverable?' do
    let(:webhook) { webhooks.default }

    it { expect(webhook).to be_deliverable }

    it 'is false when manually disabled' do
      webhook.update!(enabled: false)
      expect(webhook).not_to be_deliverable
    end

    it 'is false when auto disabled' do
      webhook.update!(auto_disabled_at: Time.current)
      expect(webhook).not_to be_deliverable
    end
  end

  describe '.subscribed_to' do
    it 'matches webhooks subscribed to the given event type' do
      expect(procedure.webhooks.subscribed_to("dossier_depose")).to include(webhooks.default)
      expect(procedure.webhooks.subscribed_to("message_cree")).not_to include(webhooks.default)
    end
  end

  describe '#backoff_delay' do
    let(:webhook) { webhooks.default }

    it 'grows exponentially from the base interval' do
      webhook.consecutive_failures = 1
      expect(webhook.backoff_delay).to eq(10.seconds)

      webhook.consecutive_failures = 5
      expect(webhook.backoff_delay).to eq(160.seconds)
    end
  end

  describe '#in_backoff?' do
    let(:webhook) { webhooks.default }

    it 'is true only inside the backoff window after a failure' do
      expect(webhook.in_backoff?).to be(false)

      webhook.update!(consecutive_failures: 3, last_attempt_at: 1.second.ago)
      expect(webhook.in_backoff?).to be(true)

      webhook.update!(last_attempt_at: 1.minute.ago)
      expect(webhook.in_backoff?).to be(false)
    end
  end

  describe 'event type floors' do
    it 'floors newly added types at the latest event and drops removed types' do
      webhook = procedure.webhooks.create!(url: "https://example.com/hook", event_types: ["dossier_depose"])
      event = WebhookEvent.create!(procedure:, dossier_id: 1, event_type: "message_cree")

      webhook.update!(event_types: ["dossier_depose", "message_cree"])
      expect(webhook.event_type_floors).to eq("message_cree" => event.id)

      webhook.update!(event_types: ["dossier_depose"])
      expect(webhook.event_type_floors).to eq({})
    end
  end
end
