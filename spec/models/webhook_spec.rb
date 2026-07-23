# frozen_string_literal: true

describe Webhook, type: :model do
  let(:procedure) { procedures.individual }

  describe 'secret' do
    it 'is generated on create in the Standard Webhooks format' do
      webhook = procedure.webhooks.create!(url: "https://example.com/hook", event_types: ["dossier_depose"])

      expect(webhook.secret).to start_with(Webhook::SECRET_PREFIX)
      key = Base64.strict_decode64(webhook.secret.delete_prefix(Webhook::SECRET_PREFIX))
      expect(key.bytesize).to eq(Webhook::SECRET_BYTES)
      expect(webhook.signing_secrets).to eq([webhook.secret])
    end
  end

  describe '#renew_secret!' do
    let(:webhook) { webhooks.default }

    it 'keeps the previous secret signing during the overlap' do
      previous = webhook.secret

      webhook.renew_secret!(overlap: 2.hours)

      expect(webhook.secret).not_to eq(previous)
      expect(webhook.signing_secrets).to eq([webhook.secret, previous])

      travel 3.hours do
        expect(webhook.signing_secrets).to eq([webhook.secret])
      end
    end

    it 'revokes the previous secret at once without overlap' do
      webhook.renew_secret!(overlap: 0.hours)

      expect(webhook.previous_secret).to be_nil
      expect(webhook.signing_secrets).to eq([webhook.secret])
    end
  end

  describe 'validations' do
    subject(:webhook) { described_class.new(procedure:, url:, event_types:) }

    let(:url) { "https://example.com/hook" }
    let(:event_types) { ["dossier_depose"] }

    it { expect(webhook).to be_valid }

    context 'with a local url' do
      let(:url) { "http://localhost/hook" }

      it do
        expect(webhook).not_to be_valid
        expect(webhook.errors).to be_of_kind(:url, :private_ip_url)
      end
    end

    context 'with a private ip url' do
      let(:url) { "https://192.168.1.1/hook" }

      it do
        expect(webhook).not_to be_valid
        expect(webhook.errors).to be_of_kind(:url, :private_ip_url)
      end
    end

    context 'with a too long url' do
      let(:url) { "https://example.com/#{'a' * Webhook::URL_MAX_LENGTH}" }

      it do
        expect(webhook).not_to be_valid
        expect(webhook.errors).to be_of_kind(:url, :too_long)
      end
    end

    context 'with a too long label' do
      before { webhook.label = 'a' * (Webhook::LABEL_MAX_LENGTH + 1) }

      it do
        expect(webhook).not_to be_valid
        expect(webhook.errors).to be_of_kind(:label, :too_long)
      end
    end

    context 'without event types' do
      let(:event_types) { [] }

      it do
        expect(webhook).not_to be_valid
        expect(webhook.errors).to be_of_kind(:event_types, :blank)
      end
    end

    context 'with an unknown event type' do
      let(:event_types) { ["dossier_depose", "unknown_event"] }

      it do
        expect(webhook).not_to be_valid
        expect(webhook.errors).to be_of_kind(:event_types, :invalid)
      end
    end

    context 'when the procedure reached the webhooks limit' do
      before do
        rows = Array.new(Webhook::MAX_PER_PROCEDURE) do |i|
          { procedure_id: procedure.id, url: "https://example.com/#{i}", secret: "secret", event_types: '{dossier_depose}', created_at: Time.current, updated_at: Time.current }
        end
        Webhook.insert_all(rows)
      end

      it do
        expect(webhook).not_to be_valid
        expect(webhook.errors).to be_of_kind(:base, :webhooks_limit_reached)
      end
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

  describe '#retry_delay' do
    let(:webhook) { webhooks.default }

    it 'follows the retry schedule, jittered' do
      webhook.consecutive_failures = 1
      expect(webhook.retry_delay).to be_within(0.5.seconds).of(5.seconds)

      webhook.consecutive_failures = 4
      expect(webhook.retry_delay).to be_within(12.minutes).of(2.hours)
    end
  end

  describe '#in_backoff?' do
    let(:webhook) { webhooks.default }

    it 'is true only until the scheduled retry' do
      expect(webhook.in_backoff?).to be(false)

      webhook.update!(retry_at: 1.minute.from_now)
      expect(webhook.in_backoff?).to be(true)

      webhook.update!(retry_at: 1.second.ago)
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
