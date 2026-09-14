# frozen_string_literal: true

class APIEntrepriseToken
  include ActiveModel::Validations

  validates :jwt_token, jwt_token: true, allow_blank: true

  TokenError = Class.new(StandardError)

  SOON_TO_EXPIRE_DELAY = 1.month

  attr_reader :jwt_token

  def initialize(jwt_token)
    @jwt_token = jwt_token
  end

  def missing? = jwt_token.blank?

  def usable? = !missing? && !expired?

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

  def can_fetch_attestation_sociale?
    # https://github.com/etalab/admin_api_entreprise/blob/6f5c7ecbe94af8d5403dbff320af56e8797f3fc6/app/policies/download_attestations_policy.rb#L16
    ['attestation_sociale', 'attestation_sociale_urssaf']
      .any? { |r| roles.include?(r) }
  end

  def can_fetch_attestation_fiscale?
    # https://github.com/etalab/admin_api_entreprise/blob/6f5c7ecbe94af8d5403dbff320af56e8797f3fc6/app/policies/download_attestations_policy.rb#L20
    ["attestation_fiscale", "attestation_fiscale_dgfip"]
      .any? { |r| roles.include?(r) }
  end

  def can_fetch_bilans_bdf?
    roles.include?("bilans_entreprise_bdf")
  end

  private

  def roles
    Array(decoded_token["roles"] || decoded_token["scopes"])
  end

  def decoded_token
    return {} if @jwt_token.blank?

    @decoded_token ||= JWT.decode(@jwt_token, nil, false)[0]
  rescue JWT::DecodeError => e
    Rails.logger.error e.message
    {}
  end
end
