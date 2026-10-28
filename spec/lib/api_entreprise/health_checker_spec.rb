# frozen_string_literal: true

RSpec.describe APIEntreprise::HealthChecker do
  before do
    APIEntreprise::HealthChecker::PROVIDERS.each_value do |key|
      Kredis.redis.del(APIEntreprise::HealthChecker.cache_key(key))
    end
  end

  describe '.provider_up?' do
    let(:ping_key) { 'dgfip/numero_tva' }

    context 'when status is ok' do
      before { cache_status(ping_key, 'ok') }

      it { expect(described_class.provider_up?(ping_key)).to be true }
    end

    context 'when status is unknown' do
      before { cache_status(ping_key, 'unknown') }

      it { expect(described_class.provider_up?(ping_key)).to be true }
    end

    context 'when status is bad_gateway' do
      before { cache_status(ping_key, 'bad_gateway') }

      it { expect(described_class.provider_up?(ping_key)).to be false }
    end

    context 'when status is maintenance' do
      before { cache_status(ping_key, 'maintenance') }

      it { expect(described_class.provider_up?(ping_key)).to be false }
    end

    context 'when cache is empty (fail-open)' do
      it { expect(described_class.provider_up?(ping_key)).to be true }
    end

    context 'when Redis is unreachable (fail-open)' do
      before { allow(Kredis.redis).to receive(:get).and_raise(Redis::CannotConnectError) }

      it { expect(described_class.provider_up?(ping_key)).to be true }
    end
  end

  describe '.refresh_all!' do
    before do
      APIEntreprise::HealthChecker::PROVIDERS.each_value do |key|
        stub_request(:get, "#{described_class::PING_BASE_URL}/#{key}")
          .to_return(status: 200, body: { status: 'ok' }.to_json)
      end
    end

    it 'caches all provider statuses' do
      described_class.refresh_all!

      APIEntreprise::HealthChecker::PROVIDERS.each_value do |key|
        expect(described_class.cached_status(key)).to eq('ok')
      end
    end

    context 'when a provider returns bad_gateway' do
      before do
        stub_request(:get, "#{described_class::PING_BASE_URL}/insee/sirene")
          .to_return(status: 502, body: { status: 'bad_gateway' }.to_json)
      end

      it 'caches the bad_gateway status' do
        described_class.refresh_all!
        expect(described_class.cached_status('insee/sirene')).to eq('bad_gateway')
      end
    end

    context 'when a provider times out' do
      before do
        stub_request(:get, "#{described_class::PING_BASE_URL}/insee/sirene").to_timeout
      end

      it 'marks the provider as down' do
        described_class.refresh_all!
        expect(described_class.provider_up?('insee/sirene')).to be false
      end
    end

    context 'when a provider returns an empty body' do
      before do
        stub_request(:get, "#{described_class::PING_BASE_URL}/insee/sirene")
          .to_return(status: 200, body: '')
      end

      it 'marks the provider as down' do
        described_class.refresh_all!
        expect(described_class.provider_up?('insee/sirene')).to be false
      end
    end

    context 'when a provider returns an HTML error page' do
      before do
        stub_request(:get, "#{described_class::PING_BASE_URL}/insee/sirene")
          .to_return(status: 500, body: '<!DOCTYPE html><html><body>500</body></html>')
      end

      it 'marks the provider as down without reporting to Sentry' do
        expect(Sentry).not_to receive(:capture_exception)

        described_class.refresh_all!

        expect(described_class.cached_status('insee/sirene')).to eq('http_500')
        expect(described_class.provider_up?('insee/sirene')).to be false
      end
    end

    context 'when a provider returns JSON without a status' do
      before do
        stub_request(:get, "#{described_class::PING_BASE_URL}/insee/sirene")
          .to_return(status: 404, body: '{}')
      end

      it 'marks the provider as down' do
        described_class.refresh_all!

        expect(described_class.cached_status('insee/sirene')).to eq('http_404')
        expect(described_class.provider_up?('insee/sirene')).to be false
      end
    end
  end

  private

  def cache_status(ping_key, status)
    Kredis.redis.set(described_class.cache_key(ping_key), status, ex: 300)
  end
end
