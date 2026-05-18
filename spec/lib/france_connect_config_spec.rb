# frozen_string_literal: true

RSpec.describe FranceConnectConfig, :caching do
  let(:base_url) { "https://fc-particulier.test/api/v2" }
  let(:jwk) { JSON::JWK.new(OpenSSL::PKey::RSA.new(2048), use: 'sig', kid: 'fc-kid-1') }
  let(:jwks) { JSON::JWK::Set.new(jwk) }

  let(:discover_response) do
    instance_double(
      OpenIDConnect::Discovery::Provider::Config::Response,
      as_json: {
        authorization_endpoint: "https://fc-particulier.test/authorize",
        token_endpoint: "https://fc-particulier.test/token",
        userinfo_endpoint: "https://fc-particulier.test/userinfo",
        end_session_endpoint: "https://fc-particulier.test/logout",
        issuer: "https://fc-particulier.test",
      },
      jwks: jwks
    )
  end

  before do
    ENV['FC_PARTICULIER_BASE_URL_V2'] = "https://fc-particulier.test"
    ENV['FC_PARTICULIER_ID_V2'] = "fc-client-id"
    ENV['FC_PARTICULIER_SECRET_V2'] = "fc-client-secret"
    ENV['APP_HOST'] = "demarche.numerique.gouv.fr"
    allow(OpenIDConnect::Discovery::Provider::Config).to receive(:discover!).with(base_url).and_return(discover_response)
  end

  after do
    ENV.delete('FC_PARTICULIER_BASE_URL_V2')
    ENV.delete('FC_PARTICULIER_ID_V2')
    ENV.delete('FC_PARTICULIER_SECRET_V2')
  end

  describe ".client_config" do
    it "merges the cached endpoints with the client credentials and canonical redirect_uri" do
      allow(Rails.env).to receive(:production?).and_return(true)

      config = described_class.client_config

      expect(config).to include(
        authorization_endpoint: "https://fc-particulier.test/authorize",
        token_endpoint: "https://fc-particulier.test/token",
        userinfo_endpoint: "https://fc-particulier.test/userinfo",
        end_session_endpoint: "https://fc-particulier.test/logout",
        issuer: "https://fc-particulier.test",
        client_id: "fc-client-id",
        identifier: "fc-client-id",
        secret: "fc-client-secret",
        redirect_uri: "https://demarche.numerique.gouv.fr/france_connect/callback"
      )
    end
  end

  describe ".jwks_for" do
    it "delegates to OidcConfig#jwks_for_raw_token" do
      raw_id_token = JSON::JWT.new(sub: "user-1", exp: 1.hour.from_now.to_i, iat: Time.current.to_i).sign(jwk, :RS256).to_s

      expect(described_class.jwks_for(raw_id_token)).to be_a(JSON::JWK::Set)
    end
  end
end
