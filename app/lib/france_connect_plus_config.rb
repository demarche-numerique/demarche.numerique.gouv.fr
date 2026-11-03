# frozen_string_literal: true

module FranceConnectPlusConfig
  module_function

  # FranceConnect+ encrypts the tokens it sends us (RSA-OAEP-256 + A256GCM) with this key
  def encryption_key = OpenSSL::PKey::RSA.new(ENV.fetch('FC_PLUS_ENC_PRIVATE_KEY'))

  def encryption_jwks = JSON::JWK::Set.new(encryption_key.public_key.to_jwk(use: 'enc', alg: 'RSA-OAEP-256'))
end
