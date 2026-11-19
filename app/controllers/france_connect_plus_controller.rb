# frozen_string_literal: true

# The FranceConnect flow, account merge included, against FranceConnect+
class FranceConnectPlusController < FranceConnectController
  ID_TOKEN_COOKIE_NAME = :france_connect_plus_id_token

  # FranceConnect+ reads here, at any time, the public key it encrypts our tokens with
  def keys
    return head :not_found if ENV['FC_PLUS_ENC_PRIVATE_KEY'].blank?

    render json: FranceConnectPlusConfig.encryption_jwks
  end

  # Where a procedure that requires FranceConnect+ sends a session opened another way
  def required; end

  private

  def service = FranceConnectPlusService
end
