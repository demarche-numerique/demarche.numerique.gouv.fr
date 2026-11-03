# frozen_string_literal: true

class ProConnectService
  include OpenIDConnect

  # https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/double_authentification
  MFA_ACR_VALUES = [
    "eidas0-mfa", # Identité : Faible ou déclarative, Auth: MFA (auto-géré), Orga: Modération ou déclaratif
    "eidas1-mfa", # Identité : Faible, Auth: MFA (auto-géré), Orga: Modération ou plus
    "eidas2",     # Identité : Substantielle, Auth: MFA (géré par l'organisation), Orga: Lien certifié par une source officielle
    "eidas3",     # Identité : Élevée, Auth: MFA matérielle (géré par l'organisation), Orga: Lien certifié par une source officielle
  ].freeze

  Authentication = Data.define(:user_info, :id_token, :amr, :acr) do
    def email = user_info['email'].strip.downcase

    def mfa? = amr.include?('mfa') || MFA_ACR_VALUES.include?(acr)
  end

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
      claims[:id_token][:acr] = { essential: true, values: MFA_ACR_VALUES }
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

  def self.authenticate(code, nonce)
    client = OpenIDConnect::Client.new(conf)
    client.authorization_code = code

    access_token = client.access_token!(client_auth_method: :secret)

    id_token = ResponseObject::IdToken.decode(access_token.id_token, ProConnectConfig.jwks_for(access_token.id_token))
    id_token.verify!(conf.merge(nonce: nonce))

    amr = id_token.amr.present? ? JSON.parse(id_token.amr) : []

    Authentication.new(user_info: access_token.userinfo!.raw_attributes, id_token: access_token.id_token, amr:, acr: id_token.acr)
  end

  def self.logout_url(id_token, host_with_port:)
    app_logout = Rails.application.routes.url_helpers.logout_url(host: host_with_port)
    h = { id_token_hint: id_token, post_logout_redirect_uri: app_logout }
    "#{conf[:end_session_endpoint]}?#{h.to_query}"
  end

  private

  # TODO: remove this block when migration to new domain is done
  def self.conf
    config = ProConnectConfig.client_config

    # rubocop:disable DS/ApplicationName
    if Current.host&.end_with?('demarche.numerique.gouv.fr')
      config[:redirect_uri] = config[:redirect_uri].gsub('www.demarches-simplifiees.fr', 'demarche.numerique.gouv.fr')
    end
    # rubocop:enable DS/ApplicationName

    config
  end
end
