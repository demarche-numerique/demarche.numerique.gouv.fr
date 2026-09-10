# frozen_string_literal: true

describe Webhooks::DeliveryJob, type: :job do
  let(:procedure) { procedures.individual }
  let(:webhook) { webhooks.default }
  let(:url) { webhook.url }

  before do
    allow(Resolv).to receive(:getaddresses).and_return(["93.184.216.34"])
  end

  def create_events(count, event_type: "dossier_depose", created_at: 1.minute.ago)
    Array.new(count) do
      WebhookEvent.create!(procedure:, dossier_id: 1, event_type:, created_at:)
    end
  end

  def perform
    described_class.perform_now(webhook.id)
  end

  describe 'successful delivery' do
    let!(:events) { create_events(2) }

    before { stub_request(:post, url).to_return(status: 200) }

    it 'posts an ordered signed batch and advances the cursor' do
      perform

      expect(WebMock).to have_requested(:post, url).with { |request|
        payload = JSON.parse(request.body)
        signature = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', webhook.secret, request.body)}"

        request.headers['Content-Type'] == 'application/json' &&
          request.headers['X-Webhook-Signature-256'] == signature &&
          payload['demarche_number'] == procedure.id &&
          payload['events'].map { it['sequence'] } == events.map(&:id) &&
          payload['events'].first['type'] == 'dossier_depose'
      }

      webhook.reload
      expect(webhook.cursor).to eq(events.last.id)
      expect(webhook.consecutive_failures).to eq(0)
      expect(webhook.last_success_at).to be_present
      expect(webhook.delivery_claimed_at).to be_nil
    end

    it 'drains the backlog in several batches' do
      create_events(Webhooks::DeliveryJob::BATCH_SIZE)

      perform

      expect(WebMock).to have_requested(:post, url).twice
      expect(webhook.reload.cursor).to eq(WebhookEvent.where(procedure:).maximum(:id))
    end

    it 'skips events the webhook is not subscribed to' do
      create_events(1, event_type: "message_cree")

      perform

      expect(webhook.reload.cursor).to eq(events.last.id)
      expect(WebMock).to have_requested(:post, url).with { |request|
        JSON.parse(request.body)['events'].none? { it['type'] == 'message_cree' }
      }
    end

    it 'pins the vetted addresses on the connection so libcurl cannot re-resolve' do
      expect(Typhoeus).to receive(:post)
        .with(url, hash_including(resolve: an_instance_of(FFI::AutoPointer), followlocation: false))
        .and_call_original

      perform
    end

    it 'leaves fresh events (within the safety lag) for a later run' do
      create_events(1, created_at: Time.current)

      perform

      expect(webhook.reload.cursor).to eq(events.last.id)
    end

    it 'never advances the cursor past a fresh event with a lower id than an older one' do
      # The timestamp is taken before the INSERT: a concurrent emitter can get
      # the lower id with the newer created_at.
      fresh = create_events(1, created_at: Time.current).first
      create_events(1, created_at: 1.minute.ago)

      perform

      expect(webhook.reload.cursor).to eq(events.last.id)
      expect(webhook.pending_events).to include(fresh)
    end
  end

  describe 'failed delivery' do
    let!(:events) { create_events(1) }

    before { stub_request(:post, url).to_return(status: 500) }

    it 'registers the failure and schedules a retry with backoff' do
      perform

      webhook.reload
      expect(webhook.cursor).to eq(0)
      expect(webhook.consecutive_failures).to eq(1)
      expect(webhook.last_error).to include("500")
      expect(Webhooks::DeliveryJob).to have_been_enqueued.with(webhook.id)
    end

    it 'auto disables the webhook and notifies administrateurs after the last attempt' do
      webhook.update!(consecutive_failures: Webhook::MAX_ATTEMPTS - 1)

      expect { perform }.to have_enqueued_mail(AdministrateurMailer, :notify_webhook_auto_disabled)

      webhook.reload
      expect(webhook.auto_disabled_at).to be_present
      expect(webhook.enabled).to be(false)
      expect(Webhooks::DeliveryJob).not_to have_been_enqueued.with(webhook.id)
    end

    it 'counts a timeout as a failure' do
      stub_request(:post, url).to_timeout

      perform

      expect(webhook.reload.consecutive_failures).to eq(1)
    end

    it 'counts a private ip resolution as a failure without any request' do
      allow(Resolv).to receive(:getaddresses).and_return(["192.168.1.1"])

      perform

      expect(webhook.reload.consecutive_failures).to eq(1)
      expect(WebMock).not_to have_requested(:post, url)
    end

    it 'blocks a resolution to an IPv4-mapped IPv6 private address' do
      allow(Resolv).to receive(:getaddresses).and_return(["::ffff:169.254.169.254"])

      perform

      expect(webhook.reload.consecutive_failures).to eq(1)
      expect(WebMock).not_to have_requested(:post, url)
    end

    it 'blocks a rebinding-style split answer (one public, one private address)' do
      allow(Resolv).to receive(:getaddresses).and_return(["93.184.216.34", "10.0.0.1"])

      perform

      expect(webhook.reload.consecutive_failures).to eq(1)
      expect(WebMock).not_to have_requested(:post, url)
    end
  end

  describe 'concurrency' do
    let!(:events) { create_events(1) }

    it 'does nothing when another delivery holds the claim' do
      webhook.update!(delivery_claimed_at: Time.current)
      stub_request(:post, url).to_return(status: 200)

      perform

      expect(WebMock).not_to have_requested(:post, url)
      expect(webhook.reload.cursor).to eq(0)
    end

    it 'recovers a stale claim' do
      webhook.update!(delivery_claimed_at: (Webhooks::DeliveryJob::CLAIM_TTL + 1.minute).ago)
      stub_request(:post, url).to_return(status: 200)

      perform

      expect(webhook.reload.cursor).to eq(events.last.id)
    end

    it 'stops without bookkeeping when the claim is cleared mid-run' do
      stub_request(:post, url).to_return do
        Webhook.where(id: webhook.id).update_all(delivery_claimed_at: nil)
        { status: 200 }
      end

      perform

      webhook.reload
      expect(webhook.cursor).to eq(0)
      expect(webhook.last_success_at).to be_nil
    end

    it 'stops without advancing the cursor when the subscription changes mid-run' do
      stub_request(:post, url).to_return do
        Webhook.find(webhook.id).update!(event_types: ["dossier_depose", "message_cree"])
        { status: 200 }
      end

      perform

      # The batch was delivered under the old subscription, but the cursor
      # must not record it: an event of the newly added type may have slipped
      # in below the batch's last id, and only a fresh run (with the new
      # event_types) can pick it up. Redelivery is fine, at-least-once.
      expect(webhook.reload.cursor).to eq(0)
    end

    it 'stops without bookkeeping when the webhook is disabled mid-run' do
      stub_request(:post, url).to_return do
        Webhook.where(id: webhook.id).update_all(enabled: false)
        { status: 500 }
      end

      perform

      webhook.reload
      expect(webhook.consecutive_failures).to eq(0)
      expect(Webhooks::DeliveryJob).not_to have_been_enqueued.with(webhook.id)
    end
  end

  describe 'disabled webhook' do
    let!(:events) { create_events(1) }

    it 'does nothing' do
      webhook.update!(enabled: false)
      stub_request(:post, url).to_return(status: 200)

      perform

      expect(WebMock).not_to have_requested(:post, url)
    end
  end

  describe 'discarded procedure' do
    let!(:events) { create_events(1) }

    it 'does not deliver the backlog while the procedure is discarded' do
      procedure.discard!
      stub_request(:post, url).to_return(status: 200)

      perform

      expect(WebMock).not_to have_requested(:post, url)
      expect(webhook.reload.cursor).to eq(0)
    end

    it 'stops without bookkeeping when the procedure is discarded mid-run' do
      stub_request(:post, url).to_return do
        Procedure.where(id: procedure.id).update_all(hidden_at: Time.current)
        { status: 200 }
      end

      perform

      expect(webhook.reload.cursor).to eq(0)
      expect(webhook.last_success_at).to be_nil
    end
  end

  describe 'backoff' do
    let!(:events) { create_events(1) }

    before { stub_request(:post, url).to_return(status: 200) }

    it 'does not attempt while inside the backoff window' do
      webhook.update!(consecutive_failures: 3, last_attempt_at: 1.second.ago)

      perform

      expect(WebMock).not_to have_requested(:post, url)
      expect(webhook.reload.cursor).to eq(0)
    end

    it 'attempts again past the backoff window' do
      webhook.update!(consecutive_failures: 3, last_attempt_at: 1.minute.ago)

      perform

      expect(webhook.reload.cursor).to eq(events.last.id)
    end
  end

  describe 'bounded runs' do
    it 'stops after MAX_BATCHES_PER_RUN batches and hands the rest to a fresh job' do
      stub_const("Webhooks::DeliveryJob::MAX_BATCHES_PER_RUN", 1)
      events = create_events(Webhooks::DeliveryJob::BATCH_SIZE + 1)
      stub_request(:post, url).to_return(status: 200)

      perform

      expect(WebMock).to have_requested(:post, url).once
      webhook.reload
      expect(webhook.cursor).to eq(events[Webhooks::DeliveryJob::BATCH_SIZE - 1].id)
      expect(webhook.delivery_claimed_at).to be_nil
      expect(Webhooks::DeliveryJob).to have_been_enqueued.with(webhook.id)
    end

    it 'does not clobber a claim taken over after an anomalous stall' do
      create_events(1)
      stolen_at = 1.minute.from_now.change(usec: 0)
      stub_request(:post, url).to_return do
        Webhook.where(id: webhook.id).update_all(delivery_claimed_at: stolen_at)
        { status: 200 }
      end

      perform

      expect(webhook.reload.delivery_claimed_at).to eq(stolen_at)
    end
  end

  describe 'event type floors' do
    it 'does not replay events recorded before the subscription to a new type' do
      create_events(2, event_type: "message_cree")
      webhook.update!(event_types: ["dossier_depose", "message_cree"])
      fresh = create_events(1, event_type: "message_cree")
      stub_request(:post, url).to_return(status: 200)

      perform

      expect(WebMock).to have_requested(:post, url).with { |request|
        JSON.parse(request.body)['events'].map { it['sequence'] } == fresh.map(&:id)
      }
      expect(webhook.reload.cursor).to eq(fresh.last.id)
    end
  end

  describe 'internal errors' do
    let!(:events) { create_events(1) }

    it 'does not count an internal error as an endpoint failure' do
      stub_request(:post, url).to_return(status: 200)
      allow(OpenSSL::HMAC).to receive(:hexdigest).and_raise("boom")

      expect { perform }.not_to raise_error

      webhook.reload
      expect(webhook.consecutive_failures).to eq(0)
      expect(webhook.last_error).to be_nil
      expect(webhook.delivery_claimed_at).to be_nil
    end
  end
end
