# frozen_string_literal: true

module ProConnectConfig
  module_function

  def client_config
    oidc.endpoints.merge(
      client_id: ENV.fetch('PRO_CONNECT_ID'),
      identifier: ENV.fetch('PRO_CONNECT_ID'),
      secret: ENV.fetch('PRO_CONNECT_SECRET'),
      redirect_uri: ENV.fetch('PRO_CONNECT_REDIRECT')
    )
  end

  def jwks = oidc.jwks

  def refresh! = oidc.refresh!

  def oidc = OidcConfig.new("pro_connect", base_url: "#{ENV.fetch('PRO_CONNECT_BASE_URL')}/api/v2")
end
