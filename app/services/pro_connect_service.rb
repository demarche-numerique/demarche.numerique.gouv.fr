# frozen_string_literal: true

class ProConnectService
  include OpenIDConnect

  def self.enabled?
    ENV['PRO_CONNECT_BASE_URL'].present?
  end

  def self.authorization_uri(force_mfa: false, login_hint: nil)
    client = OpenIDConnect::Client.new(conf)

    state = SecureRandom.hex(16)
    nonce = SecureRandom.hex(16)

    claims = {
      id_token: {
        # amr (Authentication Methods References) aka tell me how the user authenticated
        # pwd Password authentication, either by the user or the service if a client secret is used
        # mail confirmation by mail
        # totp Time-based One-Time Password
        # poph Proof of possession
        # mfa Multiple factor authentication
        amr: { essential: true },
      },
    }

    if force_mfa
      # acr (Authentication Context Class Reference) force the level of security
      # https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/double_authentification
      claims[:id_token][:acr] = {
        essential: true,
        values: [
          "eidas2", # login / pwd + 2FA
          "eidas3", # physical card with PIN + certificates
          "https://proconnect.gouv.fr/assurance/self-asserted-2fa", # declarative identity + 2FA
          "https://proconnect.gouv.fr/assurance/consistency-checked-2fa", # verified identity + 2FA
        ],
      }
    end

    uri = client.authorization_uri(
      scope: [:openid, :email, :given_name, :usual_name, :organizational_unit, :belonging_population, :siret, :idp_id],
      state:,
      nonce:,
      claims: claims.to_json,
      login_hint:,
      prompt: :login
    )

    [uri, state, nonce]
  end

  def self.user_info(code, nonce)
    client = OpenIDConnect::Client.new(conf)
    client.authorization_code = code

    access_token = client.access_token!(client_auth_method: :secret)

    id_token = ResponseObject::IdToken.decode(access_token.id_token, conf[:jwks])
    id_token.verify!(conf.merge(nonce: nonce))

    amr = id_token.amr.present? ? JSON.parse(id_token.amr) : []

    [access_token.userinfo!.raw_attributes, access_token.id_token, amr]
  end

  def self.logout_url(id_token, host_with_port:)
    app_logout = Rails.application.routes.url_helpers.logout_url(host: host_with_port)
    h = { id_token_hint: id_token, post_logout_redirect_uri: app_logout }
    "#{PRO_CONNECT[:end_session_endpoint]}?#{h.to_query}"
  end

  private

  # TODO: remove this block when migration to new domain is done
  def self.conf
    # rubocop:disable DS/ApplicationName
    if Current.host.end_with?('demarche.numerique.gouv.fr')
      h = PRO_CONNECT.dup
      h[:redirect_uri] = h[:redirect_uri].gsub('www.demarches-simplifiees.fr', 'demarche.numerique.gouv.fr')
      h
    else
      PRO_CONNECT
    end
    # rubocop:enable DS/ApplicationName
  end
end
