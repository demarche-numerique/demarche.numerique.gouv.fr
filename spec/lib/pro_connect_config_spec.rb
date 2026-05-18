# frozen_string_literal: true

RSpec.describe ProConnectConfig, :caching do
  let(:base_url) { "https://pro-connect.test/api/v2" }
  let(:jwk) { JSON::JWK.new(OpenSSL::PKey::RSA.new(2048), use: 'sig', kid: 'pc-kid-1') }
  let(:jwks) { JSON::JWK::Set.new(jwk) }

  let(:discover_response) do
    instance_double(
      OpenIDConnect::Discovery::Provider::Config::Response,
      as_json: {
        authorization_endpoint: "https://pro-connect.test/authorize",
        token_endpoint: "https://pro-connect.test/token",
        userinfo_endpoint: "https://pro-connect.test/userinfo",
        end_session_endpoint: "https://pro-connect.test/logout",
        issuer: "https://pro-connect.test",
      },
      jwks: jwks
    )
  end

  before do
    ENV['PRO_CONNECT_BASE_URL'] = "https://pro-connect.test"
    ENV['PRO_CONNECT_ID'] = "pc-client-id"
    ENV['PRO_CONNECT_SECRET'] = "pc-client-secret"
    ENV['PRO_CONNECT_REDIRECT'] = "https://www.demarches-simplifiees.fr/users/auth/pro_connect/callback"
    allow(OpenIDConnect::Discovery::Provider::Config).to receive(:discover!).with(base_url).and_return(discover_response)
  end

  after do
    ENV.delete('PRO_CONNECT_BASE_URL')
    ENV.delete('PRO_CONNECT_ID')
    ENV.delete('PRO_CONNECT_SECRET')
    ENV.delete('PRO_CONNECT_REDIRECT')
  end

  describe ".client_config" do
    it "merges the cached endpoints with the client credentials and PRO_CONNECT_REDIRECT" do
      config = described_class.client_config

      expect(config).to include(
        authorization_endpoint: "https://pro-connect.test/authorize",
        end_session_endpoint: "https://pro-connect.test/logout",
        issuer: "https://pro-connect.test",
        client_id: "pc-client-id",
        identifier: "pc-client-id",
        secret: "pc-client-secret",
        redirect_uri: "https://www.demarches-simplifiees.fr/users/auth/pro_connect/callback"
      )
    end
  end

  describe ".jwks" do
    it "delegates to OidcConfig#jwks" do
      described_class.refresh!

      expect(described_class.jwks).to be_a(JSON::JWK::Set)
    end
  end
end
