# frozen_string_literal: true

# Jeton d'API porté par une démarche (API Entreprise, API Particulier) : un JWT
# dont on lit l'expiration localement, sans vérifier la signature.
module JwtTokenConcern
  extend ActiveSupport::Concern

  SOON_TO_EXPIRE_DELAY = 1.month

  included do
    include ActiveModel::Validations

    validates :jwt_token, jwt_token: true, allow_blank: true
  end

  attr_reader :jwt_token

  def initialize(jwt_token)
    @jwt_token = jwt_token
  end

  def expired?
    return true if decoded_token.blank?

    # we have a decoded token but no exp claim, consider it as non-expiring
    return false if expires_at.nil?

    expires_at <= Time.zone.now
  end

  def expires_at
    exp = decoded_token["exp"]

    Time.zone.at(exp) if exp.present?
  end

  def expired_or_expires_soon?
    expires_at && expires_at <= SOON_TO_EXPIRE_DELAY.from_now
  end

  private

  def decoded_token
    return {} if @jwt_token.blank?

    @decoded_token ||= JWT.decode(@jwt_token, nil, false)[0]
  rescue JWT::DecodeError => e
    Rails.logger.error e.message
    {}
  end
end
