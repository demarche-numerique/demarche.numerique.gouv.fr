# frozen_string_literal: true

describe Rack::Attack, type: :request do
  let(:limit) { 30 }
  let(:period) { 15 }
  let(:ip) { "1.2.3.4" }

  before(:each) do
    ENV['RACK_ATTACK_ENABLE'] = 'true'
    setup_rack_attack_cache_store
    avoid_test_overlaps_in_cache
  end

  after do
    ENV['RACK_ATTACK_ENABLE'] = 'false'
  end

  def setup_rack_attack_cache_store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  def avoid_test_overlaps_in_cache
    Rails.cache.clear
  end

  context '/users/sign_in' do
    before do
      limit.times do
        Rack::Attack.cache.count("/users/sign_in/ip:#{ip}", period)
      end
    end

    subject do
      post "/users/sign_in", headers: { 'X-Forwarded-For': ip }
    end

    it "throttle excessive requests by IP address" do
      subject

      expect(response).to have_http_status(:too_many_requests)
    end

    context 'when the ip is whitelisted' do
      before do
        allow(IPService).to receive(:ip_trusted?).and_return(true)
        allow(ProConnectService).to receive(:enabled?).and_return(false)
        allow_any_instance_of(Users::SessionsController).to receive(:create).and_return(:ok)
      end

      it "respects the whitelist" do
        subject

        expect(response).not_to have_http_status(:too_many_requests)
      end
    end
  end

  context '/pro_connect/migration/code' do
    before do
      10.times { Rack::Attack.cache.count("/pro_connect/migration/code/ip:#{ip}", 60) }
    end

    it 'throttles the codes tried from one IP address' do
      post '/pro_connect/migration/code', headers: { 'X-Forwarded-For': ip }

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  # La création de dossier préremplie est anonyme : son throttle est la seule limite.
  context '/api/public/v1/demarches/:id/dossiers' do
    let(:limit) { 15 }

    before do
      limit.times do
        Rack::Attack.cache.count("/api/public/v1/dossiers/ip:#{ip}", period)
      end
    end

    subject do
      post "/api/public/v1/demarches/1/dossiers", headers: { 'X-Forwarded-For': ip }
    end

    it "throttle excessive requests by IP address" do
      subject

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  # The public stats endpoint is anonymous and its queries are heavy, so this
  # throttle is the only thing limiting them.
  context '/api/public/v1/demarches/:id/stats' do
    let(:limit) { 5 }

    before do
      limit.times do
        Rack::Attack.cache.count("/api/public/v1/stats/ip:#{ip}", period)
      end
    end

    it "throttle excessive requests by IP address" do
      get "/api/public/v1/demarches/1/stats", headers: { 'X-Forwarded-For': ip }

      expect(response).to have_http_status(:too_many_requests)
    end

    it "throttle them whatever format is asked for" do
      get "/api/public/v1/demarches/1/stats.json", headers: { 'X-Forwarded-For': ip }

      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
