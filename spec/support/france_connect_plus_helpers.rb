# frozen_string_literal: true

# A FranceConnect+ provider over WebMock: its tokens are signed ES256 with its
# own key, then encrypted RSA-OAEP-256 + A256GCM for ours.
module FranceConnectPlusHelpers
  # A host that resolves: WebMock opens the connection before matching the stubs (net_http_connect_on_start)
  BASE_URL = 'https://auth.integ01.dev-franceconnect.fr'
  ISSUER = "#{BASE_URL}/api/v2"
  CLIENT_ID = 'fcp_client_id'

  SIGNING_KEY = OpenSSL::PKey::EC.generate('prime256v1')
  SIGNING_PUBLIC_KEY = OpenSSL::PKey.read(SIGNING_KEY.public_to_der)
  ENCRYPTION_KEY = OpenSSL::PKey::RSA.generate(2048)

  def with_france_connect_plus_env
    env = {
      'FC_PLUS_ID' => CLIENT_ID,
      'FC_PLUS_SECRET' => 'fcp_secret',
      'FC_PLUS_BASE_URL' => BASE_URL,
      'FC_PLUS_ENC_PRIVATE_KEY' => ENCRYPTION_KEY.to_pem,
    }
    env.each { |key, value| ENV[key] = value }
    yield
  ensure
    env.each_key { ENV.delete(it) }
  end

  def stub_france_connect_plus_discovery
    stub_request(:get, "#{ISSUER}/.well-known/openid-configuration").to_return_json(body: {
      issuer: ISSUER,
      authorization_endpoint: "#{ISSUER}/authorize",
      token_endpoint: "#{ISSUER}/token",
      userinfo_endpoint: "#{ISSUER}/userinfo",
      end_session_endpoint: "#{ISSUER}/session/end",
      jwks_uri: "#{ISSUER}/jwks",
      response_types_supported: ['code'],
      subject_types_supported: ['pairwise'],
      id_token_signing_alg_values_supported: ['ES256'],
    })

    stub_request(:get, "#{ISSUER}/jwks").to_return_json(body: JSON::JWK::Set.new(JSON::JWK.new(SIGNING_PUBLIC_KEY)))
  end

  def stub_france_connect_plus_tokens(id_token:, user_info:)
    stub_request(:post, "#{ISSUER}/token").to_return_json(body: {
      access_token: 'fcp_access_token',
      token_type: 'Bearer',
      expires_in: 60,
      id_token: france_connect_plus_token(id_token),
    })

    stub_request(:get, "#{ISSUER}/userinfo")
      .with(headers: { 'Authorization' => 'Bearer fcp_access_token' })
      .to_return(body: france_connect_plus_token(user_info), headers: { 'Content-Type' => 'application/jwt' })
  end

  def france_connect_plus_id_token(nonce:, acr: 'eidas2', sub: 'fcp_sub')
    { iss: ISSUER, aud: CLIENT_ID, sub:, nonce:, acr:, exp: 1.minute.from_now.to_i, iat: Time.current.to_i }
  end

  # The kid is the key thumbprint, as in the provider's JWKS
  def france_connect_plus_signed(claims) = JSON::JWT.new(claims).sign(JSON::JWK.new(SIGNING_KEY), :ES256).to_s

  def france_connect_plus_token(claims)
    protected_header = Base64.urlsafe_encode64({ alg: 'RSA-OAEP-256', enc: 'A256GCM', cty: 'JWT' }.to_json, padding: false)

    content_key = SecureRandom.random_bytes(32)
    encrypted_key = ENCRYPTION_KEY.public_key.encrypt(content_key, {
      'rsa_padding_mode' => 'oaep',
      'rsa_oaep_md' => 'sha256',
      'rsa_mgf1_md' => 'sha256',
    })

    cipher = OpenSSL::Cipher.new('aes-256-gcm').encrypt
    cipher.key = content_key
    iv = cipher.random_iv
    cipher.auth_data = protected_header
    ciphertext = cipher.update(france_connect_plus_signed(claims)) + cipher.final

    [
      protected_header,
      *[encrypted_key, iv, ciphertext, cipher.auth_tag].map { Base64.urlsafe_encode64(it, padding: false) },
    ].join('.')
  end
end

RSpec.configure do |config|
  config.include FranceConnectPlusHelpers
end
