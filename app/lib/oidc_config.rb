# frozen_string_literal: true

class OidcConfig
  TTL = 30.days
  ENDPOINT_KEYS = [:authorization_endpoint, :token_endpoint, :userinfo_endpoint, :end_session_endpoint, :issuer].freeze

  def initialize(name, base_url:)
    @name = name
    @base_url = base_url
  end

  def endpoints = data.fetch(:endpoints)
  def jwks = JSON::JWK::Set.new(data.fetch(:jwks))

  def jwks_for_raw_token(raw_id_token)
    kid = JSON::JWT.decode(raw_id_token, :skip_verification).kid
    refresh! if jwks[kid].nil?
    jwks
  end

  def refresh!
    discover = OpenIDConnect::Discovery::Provider::Config.discover!(@base_url)
    payload = {
      endpoints: discover.as_json.slice(*ENDPOINT_KEYS),
      jwks: discover.jwks.as_json,
    }
    Rails.cache.write(cache_key, payload, expires_in: TTL)
    payload
  end

  private

  def cache_key = "oidc:#{@name}:config"
  def data = Rails.cache.read(cache_key) || refresh!
end
