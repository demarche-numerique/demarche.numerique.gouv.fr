# frozen_string_literal: true

class FranceConnectPlusController < ApplicationController
  # FranceConnect+ reads here, at any time, the public key it encrypts our tokens with
  def keys
    return head :not_found if ENV['FC_PLUS_ENC_PRIVATE_KEY'].blank?

    render json: FranceConnectPlusConfig.encryption_jwks
  end
end
