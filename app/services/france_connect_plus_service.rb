# frozen_string_literal: true

# FranceConnect+ guarantees the eIDAS « substantiel » level: same flow as
# FranceConnect, but its tokens are signed with its own keys, then encrypted for us.
class FranceConnectPlusService < FranceConnectService
  ACCEPTED_ACRS = ['eidas2', 'eidas3'].freeze

  def self.enabled? = ENV['FC_PLUS_BASE_URL'].present?

  def self.config = FranceConnectPlusConfig

  def self.acr_values = 'eidas2'

  # Decrypted, because FranceConnect+ finds the session to close from it
  def self.verified_id_token(raw_id_token, nonce)
    jws = JweDecryptor.decrypt(raw_id_token, config.encryption_key)
    id_token = OpenIDConnect::ResponseObject::IdToken.new(verified_claims(jws))
    id_token.verify!(conf.merge(nonce:))

    if !id_token.acr.in?(ACCEPTED_ACRS)
      raise OpenIDConnect::ResponseObject::IdToken::InvalidToken.new('Invalid ID token: eIDAS level below substantiel')
    end

    jws
  end

  # Not through the access token's client: its JWT middleware cannot read an encrypted body
  def self.user_info(access_token)
    response = Faraday.new.get(conf[:userinfo_endpoint], nil, { 'Authorization' => "Bearer #{access_token.access_token}" })
    raise OpenIDConnect::HttpError.new(response.status, 'Unknown HttpError', response) if response.status != 200

    verified_claims(JweDecryptor.decrypt(response.body, config.encryption_key))
  end

  def self.verified_claims(jws) = JSON::JWT.decode(jws, config.jwks_for(jws), [:ES256])
end
