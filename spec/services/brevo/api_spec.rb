# frozen_string_literal: true

describe Brevo::API do
  include Dry::Monads[:result]

  let(:api) { described_class.new }
  let(:payload) { { sender: { email: 'no-reply@example.gouv.fr' }, to: [{ email: 'usager@example.com' }], subject: 'S', htmlContent: '<p>B</p>' } }
  let(:endpoint) { "#{BREVO_API_V3_URL}/smtp/email" }

  before { allow(ENV).to receive(:fetch).with('BREVO_API_V3_KEY', nil).and_return('api-key') }

  def stub_send(status:, body:)
    stub_request(:post, endpoint)
      .with(headers: { 'api-key' => 'api-key', 'content-type' => 'application/json' }, body: payload.to_json)
      .to_return(status:, body: body.to_json, headers: { 'content-type' => 'application/json' })
  end

  def client_failure(type, code:, body: '', return_message: 'No error')
    response = instance_double(Typhoeus::Response, effective_url: endpoint, body:, code:, return_message:, total_time: 0, connect_time: 0, headers: {})
    allow(API::Client).to receive(:new).and_return(instance_double(API::Client, call: Failure(API::Client::Error[type, code, true, API::Client::HTTPError.new(response)])))
  end

  describe '#unblock_user' do
    let!(:unblock) { stub_request(:delete, %r{\Ahttps://api\.sendinblue\.com/}).to_return(status: 204) }

    it 'unblocks the address at Brevo' do
      expect(api.unblock_user('usager@example.com')).to be(true)
      expect(unblock).to have_been_requested
    end

    it 'calls nothing for an address that would leave the endpoint path' do
      expect(api.unblock_user('a/../../../webhooks/1@attacker.fr')).to be(false)
      expect(api.unblock_user('..?@attacker.fr')).to be(false)
      expect(api.unblock_user('..#@attacker.fr')).to be(false)
      expect(unblock).not_to have_been_requested
    end
  end

  describe '#blocked_contacts' do
    let(:blocked_at) { Time.zone.parse('2026-11-02 09:05') }

    def contact(email, code) = { email:, reason: { code:, message: 'Free text' }, blockedAt: '2026-11-02T08:05:00Z', senderEmail: nil }

    def stub_page(status:, body:)
      stub_request(:get, "#{BREVO_API_V3_URL}/smtp/blockedContacts")
        .with(query: { sort: 'asc', offset: '200', limit: '100' }, headers: { 'api-key' => 'api-key' })
        .to_return(status:, body: body.to_json, headers: { 'content-type' => 'application/json' })
    end

    it 'returns a page of the blocked contacts, oldest first, as webhook events' do
      stub_page(status: 200, body: { contacts: [contact('a@example.com', 'hardBounce'), contact('b@example.com', 'unsubscribedViaEmail')], count: 202 })

      expect(api.blocked_contacts(offset: 200)).to eq(Success([
        { email: 'a@example.com', event: 'hard_bounce', at: blocked_at },
        { email: 'b@example.com', event: 'unsubscribed', at: blocked_at },
      ]))
    end

    it 'gives a blocked event to a code that says nothing of the reason' do
      stub_page(status: 200, body: { contacts: [contact('a@example.com', 'adminBlocked'), contact('b@example.com', 'newBrevoCode')], count: 202 })

      expect(api.blocked_contacts(offset: 200).value!.pluck(:event)).to eq(['blocked', 'blocked'])
    end

    it 'gives no event to an unsubscription from a marketing automation or through the API' do
      stub_page(status: 200, body: { contacts: [contact('a@example.com', 'unsubscribedViaMA'), contact('b@example.com', 'unsubscribedViaApi')], count: 202 })

      expect(api.blocked_contacts(offset: 200).value!.pluck(:event)).to eq([nil, nil])
    end

    it 'reads the blocks of a single day' do
      page = stub_request(:get, "#{BREVO_API_V3_URL}/smtp/blockedContacts")
        .with(query: { sort: 'asc', offset: '0', limit: '100', startDate: '2026-11-02', endDate: '2026-11-02' })
        .to_return(status: 200, body: { count: 0 }.to_json, headers: { 'content-type' => 'application/json' })

      api.blocked_contacts(offset: 0, day: Date.new(2026, 11, 2))

      expect(page).to have_been_requested
    end

    it 'returns no contact past the last page' do
      stub_page(status: 200, body: { count: 200 })

      expect(api.blocked_contacts(offset: 200)).to eq(Success([]))
    end

    it 'classifies a failure' do
      stub_page(status: 429, body: { code: 'too_many_requests', message: 'Rate limit' })

      expect(api.blocked_contacts(offset: 200).failure).to have_attributes(kind: :throttled, http_code: 429)
    end
  end

  describe '#send_email' do
    it 'returns the message ids' do
      stub_send(status: 201, body: { messageId: '<1@smtp-relay.mailin.fr>' })
      expect(api.send_email(payload)).to eq(Success(['<1@smtp-relay.mailin.fr>']))

      stub_send(status: 201, body: { messageIds: ['<1@smtp-relay.mailin.fr>', '<2@smtp-relay.mailin.fr>'] })
      expect(api.send_email(payload)).to eq(Success(['<1@smtp-relay.mailin.fr>', '<2@smtp-relay.mailin.fr>']))
    end

    it 'classifies by Brevo code before HTTP status' do
      stub_send(status: 400, body: { code: 'not_enough_credits', message: 'Not enough credits' })
      expect(api.send_email(payload).failure).to have_attributes(kind: :account, http_code: 400, brevo_code: 'not_enough_credits')

      stub_send(status: 400, body: { code: 'duplicate_request', message: 'Identical request submitted too frequently' })
      expect(api.send_email(payload).failure).to have_attributes(kind: :duplicate)

      stub_send(status: 400, body: { code: 'invalid_parameter', message: 'email usager@example.com is not valid in to' })
      expect(api.send_email(payload).failure).to have_attributes(kind: :rejected, brevo_code: 'invalid_parameter', message: 'email [email] is not valid in to')
    end

    it 'retries what Brevo did not reject: throttling, account, server and proxy errors' do
      stub_send(status: 429, body: { code: 'too_many_requests', message: 'Rate limit' })
      expect(api.send_email(payload).failure).to have_attributes(kind: :throttled)

      stub_request(:post, endpoint).to_return(status: 502, body: '<html>Bad gateway</html>')
      expect(api.send_email(payload).failure).to have_attributes(kind: :outage, type: :http, http_code: 502, brevo_code: nil)

      stub_request(:post, endpoint).to_return(status: 401, body: '')
      expect(api.send_email(payload).failure).to have_attributes(kind: :account)

      stub_request(:post, endpoint).to_return(status: 404, body: '<html>Not found</html>')
      expect(api.send_email(payload).failure).to have_attributes(kind: :outage)
    end

    it 'keeps the curl message of a transport failure, not of an HTTP error' do
      client_failure(:network, code: 0, return_message: "Couldn't resolve host name")
      expect(api.send_email(payload).failure).to have_attributes(kind: :outage, message: "Couldn't resolve host name")

      client_failure(:http, code: 502, body: '<html>Bad gateway</html>')
      expect(api.send_email(payload).failure).to have_attributes(kind: :outage, message: nil)
    end
  end
end
