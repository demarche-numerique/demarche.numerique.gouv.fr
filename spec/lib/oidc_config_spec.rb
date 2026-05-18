# frozen_string_literal: true

RSpec.describe OidcConfig, :caching do
  let(:base_url) { "https://example.com/api/v2" }
  let(:config) { described_class.new("test_provider", base_url:) }
  let(:cache_key) { "oidc:test_provider:config" }

  let(:rsa_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:jwk) { JSON::JWK.new(rsa_key, use: 'sig', kid: 'kid-1') }
  let(:jwks) { JSON::JWK::Set.new(jwk) }

  let(:discover_response) do
    instance_double(
      OpenIDConnect::Discovery::Provider::Config::Response,
      as_json: {
        authorization_endpoint: "https://example.com/authorize",
        token_endpoint: "https://example.com/token",
        userinfo_endpoint: "https://example.com/userinfo",
        end_session_endpoint: "https://example.com/logout",
        issuer: "https://example.com",
      },
      jwks: jwks
    )
  end

  before do
    allow(OpenIDConnect::Discovery::Provider::Config).to receive(:discover!).with(base_url).and_return(discover_response)
  end

  describe "#endpoints" do
    it "returns the cached endpoints without a network call when populated" do
      config.refresh!

      expect(OpenIDConnect::Discovery::Provider::Config).not_to receive(:discover!)
      endpoints = described_class.new("test_provider", base_url:).endpoints
      expect(endpoints).to eq(
        authorization_endpoint: "https://example.com/authorize",
        token_endpoint: "https://example.com/token",
        userinfo_endpoint: "https://example.com/userinfo",
        end_session_endpoint: "https://example.com/logout",
        issuer: "https://example.com"
      )
    end

    it "triggers a lazy refresh when the cache is empty" do
      expect(config.endpoints[:authorization_endpoint]).to eq "https://example.com/authorize"
      expect(OpenIDConnect::Discovery::Provider::Config).to have_received(:discover!).with(base_url)
    end
  end

  describe "#refresh!" do
    it "fetches and writes endpoints + jwks to Rails.cache with a 30-day TTL" do
      expect(Rails.cache).to receive(:write).with(cache_key, hash_including(:endpoints, :jwks), expires_in: 30.days).and_call_original
      config.refresh!

      expect(JSON::JWK::Set.new(Rails.cache.read(cache_key)[:jwks])['kid-1']).to be_present
    end
  end

  describe "#jwks" do
    it "returns a JSON::JWK::Set rebuilt from the cached payload" do
      config.refresh!

      expect(OpenIDConnect::Discovery::Provider::Config).not_to receive(:discover!)
      set = described_class.new("test_provider", base_url:).jwks
      expect(set).to be_a(JSON::JWK::Set)
      expect(set['kid-1']).to be_present
    end
  end

  describe "#jwks_for_raw_token" do
    let(:raw_id_token) { signed_token_with(jwk) }

    def signed_token_with(signing_jwk)
      JSON::JWT.new(sub: "user-1", iss: "https://example.com", aud: "client", exp: 1.hour.from_now.to_i, iat: Time.current.to_i).sign(signing_jwk, :RS256).to_s
    end

    it "returns the cached JWKS without a network call when the kid matches" do
      config.refresh!

      expect(OpenIDConnect::Discovery::Provider::Config).not_to receive(:discover!)
      result = config.jwks_for_raw_token(raw_id_token)
      expect(result.map { |k| k[:kid] }).to include('kid-1')
    end

    it "re-fetches when the kid is missing from the cached JWKS" do
      config.refresh!

      rotated_jwk = JSON::JWK.new(OpenSSL::PKey::RSA.new(2048), use: 'sig', kid: 'kid-2')
      rotated_response = instance_double(
        OpenIDConnect::Discovery::Provider::Config::Response,
        as_json: discover_response.as_json,
        jwks: JSON::JWK::Set.new(rotated_jwk)
      )
      allow(OpenIDConnect::Discovery::Provider::Config).to receive(:discover!).with(base_url).and_return(rotated_response)

      result = config.jwks_for_raw_token(signed_token_with(rotated_jwk))
      expect(result.map { |k| k[:kid] }).to include('kid-2')
    end
  end
end
