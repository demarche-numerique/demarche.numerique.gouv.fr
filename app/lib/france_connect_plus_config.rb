# frozen_string_literal: true

module FranceConnectPlusConfig
  module_function

  def client_config
    oidc.endpoints.merge(
      client_id: ENV.fetch('FC_PLUS_ID'),
      identifier: ENV.fetch('FC_PLUS_ID'),
      secret: ENV.fetch('FC_PLUS_SECRET'),
      redirect_uri: "#{protocol}://#{ENV.fetch('APP_HOST')}/france_connect_plus/callback"
    )
  end

  def jwks_for(raw_id_token) = oidc.jwks_for_raw_token(raw_id_token)

  def refresh! = oidc.refresh!

  def oidc = OidcConfig.new("france_connect_plus", base_url: "#{ENV.fetch('FC_PLUS_BASE_URL')}/api/v2")

  def protocol = Rails.env.production? ? 'https' : 'http'

  # FranceConnect+ encrypts the tokens it sends us (RSA-OAEP-256 + A256GCM) with this key
  def encryption_key = OpenSSL::PKey::RSA.new(ENV.fetch('FC_PLUS_ENC_PRIVATE_KEY'))

  def encryption_jwks = JSON::JWK::Set.new(encryption_key.public_key.to_jwk(use: 'enc', alg: 'RSA-OAEP-256'))
end
