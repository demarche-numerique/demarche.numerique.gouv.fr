# frozen_string_literal: true

describe SentryFingerprint do
  def fingerprint_for(hint)
    event = Sentry::ErrorEvent.new(configuration: Sentry.configuration)
    described_class.call(event, hint).fingerprint
  end

  # Raises `inner`, then raises the exception built by the block from the
  # rescue clause, so the result carries `inner` as its cause.
  def raise_wrapped(inner)
    begin
      raise inner
    rescue StandardError
      raise yield
    end
  rescue StandardError => e
    e
  end

  describe '.call' do
    it 'is wired as the Sentry before_send hook' do
      # No DSN in test: the client runs before_send and skips the transport.
      event = Sentry::ErrorEvent.new(configuration: Sentry.configuration)
      exception = Redis::CannotConnectError.new('Connection refused')
      expect(Sentry.get_current_client.send_event(event, { exception: }).fingerprint).to eq(['Redis::CannotConnectError'])
    end

    it 'groups a Redis connection error by class, whatever the message' do
      ['Connection refused', 'Connection timed out', 'No route to host', ''].each do |message|
        expect(fingerprint_for(exception: Redis::CannotConnectError.new(message))).to eq(['Redis::CannotConnectError'])
      end
    end

    it 'groups a wrapped database connection error by the infrastructure class' do
      exception = raise_wrapped(ActiveRecord::DatabaseConnectionError.new('There is an issue connecting with your hostname')) do
        ActiveJob::DeserializationError.new
      end
      expect(fingerprint_for(exception:)).to eq(['ActiveRecord::DatabaseConnectionError'])
    end

    it 'groups a PostgreSQL connection failure by the outermost infrastructure class' do
      exception = raise_wrapped(PG::ConnectionBad.new('PQconsumeInput() server closed the connection unexpectedly')) do
        ActiveRecord::ConnectionFailed.new('PQconsumeInput() server closed the connection unexpectedly')
      end
      expect(fingerprint_for(exception:)).to eq(['ActiveRecord::ConnectionFailed'])
    end

    it 'groups Sidekiq redis-client errors by class' do
      expect(fingerprint_for(exception: RedisClient::CannotConnectError.new('timeout 1.0s'))).to eq(['RedisClient::CannotConnectError'])
    end

    it 'groups object storage socket and 5xx errors by class' do
      expect(fingerprint_for(exception: Excon::Error::BadGateway.new('Expected(200) <=> Actual(502 Bad Gateway)'))).to eq(['Excon::Error::BadGateway'])
      expect(fingerprint_for(exception: Excon::Error::Socket.new(Errno::ECONNREFUSED.new))).to eq(['Excon::Error::Socket'])
    end

    it 'groups Redis LOADING errors but not other command errors' do
      loading = Redis::CommandError.new('LOADING Redis is loading the dataset in memory')
      expect(fingerprint_for(exception: loading)).to eq(['Redis::CommandError'])

      wrong_type = Redis::CommandError.new('WRONGTYPE Operation against a key holding the wrong kind of value')
      expect(fingerprint_for(exception: wrong_type)).to be_empty
    end

    it 'groups a provider outage by provider, whatever the message or the wrapped error' do
      timeout = RetryableFetchError.new(StandardError.new('API Entreprise: timeout'), provider: 'Champs::SiretChamp')
      degraded = RetryableFetchError.new(StandardError.new('API Entreprise: degraded mode'), provider: 'Champs::SiretChamp')
      expect(fingerprint_for(exception: timeout)).to eq(['provider-outage', 'Champs::SiretChamp'])
      expect(fingerprint_for(exception: degraded)).to eq(['provider-outage', 'Champs::SiretChamp'])

      upstream = APIEntreprise::Job::UpstreamError.new('API Entreprise error: type=server_error code=502', provider: 'APIEntreprise::ExercicesJob')
      expect(fingerprint_for(exception: upstream)).to eq(['provider-outage', 'APIEntreprise::ExercicesJob'])
    end

    it 'groups Brevo API errors by kind and Brevo code, outages by provider' do
      error = -> (kind, code) { Brevo::API::Error[kind, :http, 400, code, 'message'] }

      expect(fingerprint_for(exception: Brevo::APIDeliveryMethod::OutageError.new(error[:outage, nil]))).to eq(['provider-outage', 'brevo'])
      expect(fingerprint_for(exception: Brevo::APIDeliveryMethod::RejectedError.new(error[:rejected, 'invalid_parameter']))).to eq(['brevo-rejected', 'invalid_parameter'])
      expect(fingerprint_for(exception: Brevo::APIDeliveryMethod::AccountError.new(error[:account, nil]))).to eq(['brevo-account'])

      recording_failure = raise_wrapped(Brevo::APIDeliveryMethod::RejectedError.new(error[:rejected, 'invalid_parameter'])) do
        ActiveRecord::StatementInvalid.new('PG::QueryCanceled')
      end
      expect(fingerprint_for(exception: recording_failure)).to be_empty
    end

    it 'lets an infrastructure error wrapped in a provider outage win' do
      wrapped = RetryableFetchError.new(Redis::CannotConnectError.new('Connection refused'), provider: 'Champs::SiretChamp')
      expect(fingerprint_for(exception: wrapped)).to eq(['Redis::CannotConnectError'])
    end

    it 'leaves other errors, statement timeouts and messages to the default grouping' do
      expect(fingerprint_for(exception: RuntimeError.new('boom'))).to be_empty
      expect(fingerprint_for(exception: ActiveRecord::QueryCanceled.new('canceling statement'))).to be_empty
      expect(fingerprint_for(exception: Excon::Error::Conflict.new('Expected(202) <=> Actual(409 Conflict)'))).to be_empty
      expect(fingerprint_for(message: 'hello')).to be_empty
    end
  end
end
