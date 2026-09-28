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
