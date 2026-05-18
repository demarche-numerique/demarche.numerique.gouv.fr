# frozen_string_literal: true

class FranceConnectService
  UPDATABLE_FRANCE_CONNECT_CLAIMS = {
    birthdate: 'birthdate',
    birthplace: 'birthplace',
    email_france_connect: 'email',
    family_name: 'family_name',
    gender: 'gender',
    given_name: 'given_name',
    birthcountry: 'birthcountry',
  }.freeze

  def self.enabled?
    ENV.fetch("FRANCE_CONNECT_ENABLED", "enabled") == "enabled" && ENV['FC_PARTICULIER_BASE_URL_V2'].present?
  end

  def self.authorization_uri
    client = OpenIDConnect::Client.new(conf)

    state = SecureRandom.alphanumeric(32)
    nonce = SecureRandom.alphanumeric(32)

    uri = client.authorization_uri(
      scope: [:identite_pivot, :email],
      state:,
      nonce:,
      acr_values: 'eidas1'
    )

    [uri, state, nonce]
  end

  def self.find_or_retrieve_france_connect_information(code, nonce)
    user_info, id_token = retrieve_user_informations(code, nonce)

    france_connect_particulier_id = user_info['sub']
    fci = FranceConnectInformation.find_or_initialize_by(france_connect_particulier_id:)

    fci.update(UPDATABLE_FRANCE_CONNECT_CLAIMS.transform_values { |fc_claim| user_info[fc_claim] })

    [fci, id_token]
  end

  def self.logout_url(id_token:, state:, callback:)
    h = { id_token_hint: id_token, state:, post_logout_redirect_uri: callback }
    "#{conf[:end_session_endpoint]}?#{h.to_query}"
  end

  private

  def self.retrieve_user_informations(code, nonce)
    client = OpenIDConnect::Client.new(conf)
    client.authorization_code = code

    access_token = client.access_token!(client_auth_method: :secret)

    id_token = OpenIDConnect::ResponseObject::IdToken.decode(access_token.id_token, FranceConnectConfig.jwks)

    id_token.verify!(conf.merge(nonce:))

    user_info = access_token.userinfo!.raw_attributes

    [user_info, access_token.id_token]
  rescue OpenIDConnect::HttpError => e
    Sentry.set_extras(france_connect_status: e.status, france_connect_body: e.response.body)
    raise
  end

  # rubocop:disable DS/ApplicationName
  ALLOWED_HOSTS = %w[demarche.numerique.gouv.fr www.demarches-simplifiees.fr].freeze
  # rubocop:enable DS/ApplicationName

  def self.conf
    config = FranceConnectConfig.client_config

    # TODO: remove this block when migration to new domain is done
    # dirty hack to redirect to the right domain
    if !Rails.env.test? && Current.host != ENV.fetch("APP_HOST") && ALLOWED_HOSTS.include?(Current.host)
      config[:redirect_uri] = config[:redirect_uri].sub("//#{ENV.fetch("APP_HOST")}/", "//#{Current.host}/")
    end

    config
  end
end
