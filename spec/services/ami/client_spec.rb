# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ami::Client do
  let(:service) { described_class.new }
  let(:payload) { { event: { state: "accepte" } } }
  let(:api_client) { instance_double(API::Client) }
  let(:response) { double(code: 200, body: '{"ok":true}') }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("AMI_API_URL", nil).and_return("https://ami.example.org")
    allow(ENV).to receive(:fetch).with("AMI_API_USER", nil).and_return("ami-user")
    allow(ENV).to receive(:fetch).with("AMI_API_PASSWORD", nil).and_return("ami-password")
    allow(API::Client).to receive(:new).and_return(api_client)
  end

  it 'returns success when API call succeeds' do
    allow(api_client).to receive(:call).and_return(
      Dry::Monads::Success(API::Client::OK[{ ok: true }, response])
    )

    result = service.send_notification(payload)

    expect(api_client).to have_received(:call).with(
      url: URI("https://ami.example.org#{described_class::EVENT_PATH}"),
      json: payload,
      method: :put,
      userpwd: "ami-user:ami-password"
    )
    expect(result).to be_success
    expect(result.value!).to eq({ ok: true })
  end

  it 'returns failure when API returns 4xx' do
    allow(api_client).to receive(:call).and_return(
      Dry::Monads::Failure(API::Client::Error[:http, 400, false, "Bad request"])
    )

    result = service.send_notification(payload)

    expect(result).to be_failure
    expect(result.failure.type).to eq(:http)
    expect(result.failure.code).to eq(400)
    expect(result.failure.retryable).to be(false)
  end

  describe 'logging' do
    before { allow(Rails.logger).to receive(:info) }

    it 'traces a failed call with the status AMI answered' do
      allow(Rails.env).to receive(:development?).and_return(true)
      allow(api_client).to receive(:call).and_return(
        Dry::Monads::Failure(API::Client::Error[:http, 404, false, "Not found"])
      )

      service.send_notification(payload)

      expect(Rails.logger).to have_received(:info).with("[AMI] PUT /api/v2/event → 404")
    end

    it 'traces a successful call with the status AMI answered' do
      allow(Rails.env).to receive(:development?).and_return(true)
      allow(api_client).to receive(:call).and_return(Dry::Monads::Success(API::Client::OK[{}, response]))

      service.send_notification(payload)

      expect(Rails.logger).to have_received(:info).with("[AMI] PUT /api/v2/event → 200")
    end

    it 'stays quiet outside development' do
      allow(api_client).to receive(:call).and_return(Dry::Monads::Success(API::Client::OK[{}, response]))

      service.send_notification(payload)

      expect(Rails.logger).not_to have_received(:info)
    end
  end

  describe '#consent' do
    it 'reads the consent of a France Connect identity' do
      allow(api_client).to receive(:call).and_return(
        Dry::Monads::Success(API::Client::OK[{}, response])
      )

      result = service.consent("abc123")

      expect(api_client).to have_received(:call).with(
        url: URI("https://ami.example.org/api/v1/consent/abc123"),
        method: :get,
        userpwd: "ami-user:ami-password",
        timeout: described_class::CONSENT_READ_TIMEOUT
      )
      expect(result).to be_success
    end

    # AMI answers 200 without a body, which API::Client cannot parse as JSON
    it 'returns success when AMI answers 200 with an empty body' do
      allow(api_client).to receive(:call).and_return(
        Dry::Monads::Failure(API::Client::Error[:json, 200, false, "unexpected end of input"])
      )

      expect(service.consent("abc123")).to be_success
    end

    it 'returns failure when AMI answers 404' do
      allow(api_client).to receive(:call).and_return(
        Dry::Monads::Failure(API::Client::Error[:http, 404, false, "Not found"])
      )

      result = service.consent("abc123")

      expect(result).to be_failure
      expect(result.failure.code).to eq(404)
    end
  end

  describe '#grant_consent' do
    it 'sends the consent of a France Connect identity' do
      allow(api_client).to receive(:call).and_return(
        Dry::Monads::Success(API::Client::OK[{ message: "Consent given" }, double])
      )

      result = service.grant_consent("abc123")

      expect(api_client).to have_received(:call).with(
        url: URI("https://ami.example.org#{described_class::CONSENT_PATH}/abc123"),
        json: { consent: true },
        method: :post,
        userpwd: "ami-user:ami-password",
        timeout: described_class::CONSENT_WRITE_TIMEOUT
      )
      expect(result).to be_success
    end

    # AMI a répondu sans corps par le passé ; le contrat en promet un désormais,
    # mais requalifier reste inoffensif et couvre les deux formes.
    it 'accepts an empty body' do
      allow(api_client).to receive(:call).and_return(
        Dry::Monads::Failure(API::Client::Error[:json, 201, false, "unexpected end of input"])
      )

      expect(service.grant_consent("abc123")).to be_success
    end

    it 'returns failure when AMI rejects the call' do
      allow(api_client).to receive(:call).and_return(
        Dry::Monads::Failure(API::Client::Error[:http, 500, true, "Boom"])
      )

      expect(service.grant_consent("abc123")).to be_failure
    end
  end

  it 'returns retryable failure when API times out' do
    timeout_error = API::Client::HTTPError.new(
      double(
        effective_url: "https://ami.example.org/api/v1/notifications",
        code: 0,
        body: "",
        return_message: "Operation timed out",
        total_time: 5.0,
        connect_time: 1.0,
        headers: {}
      )
    )
    allow(api_client).to receive(:call).and_return(
      Dry::Monads::Failure(API::Client::Error[:timeout, 0, true, timeout_error])
    )

    result = service.send_notification(payload)

    expect(result).to be_failure
    expect(result.failure.type).to eq(:timeout)
    expect(result.failure.retryable).to be(true)
  end
end
