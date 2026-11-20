# frozen_string_literal: true

describe Webhooks::DeliveryJob, type: :job do
  let(:procedure) { procedures.individual }
  let(:webhook) { webhooks.default }
  let(:url) { webhook.url }

  before do
    allow(Resolv).to receive(:getaddresses).and_return(["93.184.216.34"])
    webhook.debounce_delivery_flag.remove
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

    # the official Standard Webhooks library, as integrators will use it
    def verified_with?(secret, request)
      StandardWebhooks::Webhook.new(secret).verify(request.body, request.headers.transform_keys(&:downcase))
      true
    rescue StandardWebhooks::WebhookVerificationError
      false
    end

    it 'posts an ordered batch signed per Standard Webhooks and advances the cursor' do
      perform

      expect(WebMock).to have_requested(:post, url).with { |request|
        payload = JSON.parse(request.body)

        request.headers['Content-Type'] == 'application/json' &&
          request.headers['Webhook-Id'] == "msg_#{webhook.id}_#{events.first.id}_#{events.last.id}" &&
          verified_with?(webhook.secret, request) &&
          !verified_with?(Webhook.generate_secret, request) &&
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

    it 'skips events the webhook is not subscribed to, cursor included' do
      other = create_events(1, event_type: "message_cree").first

      perform

      expect(webhook.reload.cursor).to eq(other.id)
      expect(WebMock).to have_requested(:post, url).with { |request|
        JSON.parse(request.body)['events'].none? { it['type'] == 'message_cree' }
      }
    end

    it 'signs with both secrets during a renewal overlap' do
      previous = webhook.secret
      webhook.renew_secret!(overlap: 1.hour)

      perform

      expect(WebMock).to have_requested(:post, url).with { |request|
        request.headers['Webhook-Signature'].split(' ').size == 2 &&
          verified_with?(webhook.secret, request) &&
          verified_with?(previous, request)
      }
    end

    it 'requests the ASCII form of the url, the one the pin is for' do
      webhook.update!(url: "HTTPS://Exämple.fr/hook")
      stub_request(:post, "https://xn--exmple-cua.fr/hook").to_return(status: 200)

      expect(Typhoeus).to receive(:post).with("https://xn--exmple-cua.fr/hook", anything).and_call_original

      perform

      expect(webhook.reload.cursor).to eq(events.last.id)
    end

    it 'pins the vetted addresses on the connection so libcurl cannot re-resolve, and caps the response size' do
      expect(Typhoeus).to receive(:post)
        .with(url, hash_including(resolve: an_instance_of(FFI::AutoPointer), followlocation: false, maxfilesize: described_class::MAX_RESPONSE_SIZE))
        .and_call_original

      perform
    end

    it 'leaves fresh events (within the safety lag) to a follow-up run' do
      create_events(1, created_at: Time.current)

      perform

      expect(webhook.reload.cursor).to eq(events.last.id)
      expect(Webhooks::DeliveryJob).to have_been_enqueued.with(webhook.id)
    end

    it 'schedules no follow-up once everything is delivered' do
      perform

      expect(webhook.reload.cursor).to eq(events.last.id)
      expect(Webhooks::DeliveryJob).not_to have_been_enqueued
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

    it 'never moves the cursor past an event committed after an empty read' do
      late = nil
      job = described_class.new(webhook.id)
      allow(job).to receive(:pending_events).and_wrap_original do |original, *args|
        original.call(*args).tap { |read| late ||= create_events(1, created_at: Time.current).first if read.empty? }
      end

      job.perform_now

      expect(webhook.reload.cursor).to eq(events.last.id)
      expect(webhook.pending_events).to include(late)
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
      expect(webhook.retry_at).to be_within(1.second).of(Webhook::RETRY_SCHEDULE.first.from_now)
      expect(Webhooks::DeliveryJob).to have_been_enqueued.with(webhook.id).at(webhook.retry_at)
    end

    it 'auto disables the webhook and notifies administrateurs after the last attempt' do
      webhook.update!(consecutive_failures: Webhook::MAX_ATTEMPTS - 1)

      expect { perform }.to have_enqueued_mail(AdministrateurMailer, :notify_webhook_auto_disabled)

      webhook.reload
      expect(webhook.auto_disabled_at).to be_present
      expect(webhook.enabled).to be(false)
      expect(Webhooks::DeliveryJob).not_to have_been_enqueued.with(webhook.id)
    end

    it 'disables at once and notifies when the endpoint answers 410 Gone' do
      stub_request(:post, url).to_return(status: 410)

      expect { perform }.to have_enqueued_mail(AdministrateurMailer, :notify_webhook_auto_disabled)
        .with(administrateurs.default, webhook, gone: true)

      webhook.reload
      expect(webhook.enabled).to be(false)
      expect(webhook.auto_disabled_at).to be_present
      expect(webhook.consecutive_failures).to eq(1)
      expect(Webhooks::DeliveryJob).not_to have_been_enqueued.with(webhook.id)
    end

    it 'waits as long as Retry-After asks when longer than the schedule' do
      stub_request(:post, url).to_return(status: 429, headers: { 'Retry-After' => '120' })

      perform

      expect(webhook.reload.retry_at).to be_within(1.second).of(120.seconds.from_now)
    end

    it 'reads Retry-After as an HTTP date' do
      stub_request(:post, url).to_return(status: 503, headers: { 'Retry-After' => 1.hour.from_now.httpdate })

      perform

      expect(webhook.reload.retry_at).to be_within(2.seconds).of(1.hour.from_now)
    end

    it 'caps Retry-After at the longest step of the schedule' do
      stub_request(:post, url).to_return(status: 429, headers: { 'Retry-After' => 1.week.to_i.to_s })

      perform

      expect(webhook.reload.retry_at).to be_within(1.second).of(Webhook::RETRY_SCHEDULE.last.from_now)
    end

    it 'keeps the schedule when Retry-After is shorter or unreadable' do
      webhook.update!(consecutive_failures: 2)
      stub_request(:post, url).to_return(status: 429, headers: { 'Retry-After' => 'soon' })

      perform

      expect(webhook.reload.retry_at).to be_within(4.minutes).of(30.minutes.from_now)
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
      expect(webhook.last_error).to eq("L'URL du webhook n'est pas autorisée")
      expect(WebMock).not_to have_requested(:post, url)
    end

    it 'reports an unresolvable host as it does a private one' do
      allow(Resolv).to receive(:getaddresses).and_return([])

      perform

      expect(webhook.reload.consecutive_failures).to eq(1)
      expect(webhook.last_error).to eq("L'URL du webhook n'est pas autorisée")
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

    it 'reads the webhook under the claim, not before' do
      stub_request(:post, url).to_return(status: 200)
      job = described_class.new(webhook.id)
      # another run delivers the event and releases just before this one claims
      allow(job).to receive(:claim).and_wrap_original do |original, *args|
        Webhook.where(id: webhook.id).update_all(cursor: events.last.id)
        original.call(*args)
      end

      job.perform_now

      expect(WebMock).not_to have_requested(:post, url)
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

    it 'records no failure when the claim is cleared mid-run' do
      stub_request(:post, url).to_return do
        Webhook.where(id: webhook.id).update_all(delivery_claimed_at: nil)
        { status: 500 }
      end

      perform

      webhook.reload
      expect(webhook.consecutive_failures).to eq(0)
      expect(webhook.last_error).to be_nil
      expect(Webhooks::DeliveryJob).not_to have_been_enqueued.with(webhook.id)
    end

    it 'counts a failure from zero when the backoff is cleared mid-run' do
      webhook.update!(consecutive_failures: Webhook::MAX_ATTEMPTS - 1)
      stub_request(:post, url).to_return do
        Webhook.find(webhook.id).clear_backoff!
        { status: 500 }
      end

      perform

      webhook.reload
      expect(webhook.consecutive_failures).to eq(1)
      expect(webhook.enabled).to be(true)
      expect(Webhooks::DeliveryJob).to have_been_enqueued.with(webhook.id)
    end

    it 'stops without advancing the cursor when the subscription changes mid-run' do
      stub_request(:post, url).to_return do
        Webhook.find(webhook.id).update!(event_types: ["dossier_depose", "message_cree"])
        { status: 200 }
      end

      perform

      # the new subscription may select an event below the batch's last id
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
      webhook.update!(consecutive_failures: 3, retry_at: 1.minute.from_now)

      perform

      expect(WebMock).not_to have_requested(:post, url)
      expect(webhook.reload.cursor).to eq(0)
    end

    it 'attempts again past the backoff window' do
      webhook.update!(consecutive_failures: 3, retry_at: 1.second.ago)

      perform

      expect(webhook.reload.cursor).to eq(events.last.id)
    end
  end

  describe 'events of other types' do
    before { stub_request(:post, url).to_return(status: 200) }

    it 'moves the cursor over them without recording a delivery' do
      others = create_events(2, event_type: "message_cree")

      expect { perform }.not_to change { webhook.reload.last_success_at }
      expect(webhook.cursor).to eq(others.last.id)
    end

    it 'stays below the safety lag' do
      other = create_events(1, event_type: "message_cree").first
      create_events(1, event_type: "message_cree", created_at: Time.current)

      perform

      expect(webhook.reload.cursor).to eq(other.id)
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
      allow(OpenSSL::HMAC).to receive(:digest).and_raise("boom")

      expect { perform }.not_to raise_error

      webhook.reload
      expect(webhook.consecutive_failures).to eq(0)
      expect(webhook.last_error).to be_nil
      expect(webhook.delivery_claimed_at).to be_nil
    end
  end
end
