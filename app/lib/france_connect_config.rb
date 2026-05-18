# frozen_string_literal: true

module FranceConnectConfig
  module_function

  def client_config
    oidc.endpoints.merge(
      client_id: ENV.fetch('FC_PARTICULIER_ID_V2'),
      identifier: ENV.fetch('FC_PARTICULIER_ID_V2'),
      secret: ENV.fetch('FC_PARTICULIER_SECRET_V2'),
      redirect_uri: "#{protocol}://#{ENV.fetch('APP_HOST')}/france_connect/callback"
    )
  end

  def jwks = oidc.jwks

  def refresh! = oidc.refresh!

  def oidc = OidcConfig.new("france_connect", base_url: "#{ENV.fetch('FC_PARTICULIER_BASE_URL_V2')}/api/v2")

  def protocol = Rails.env.production? ? 'https' : 'http'
end
