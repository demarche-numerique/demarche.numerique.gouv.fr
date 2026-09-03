# frozen_string_literal: true

module APIParticulierTokenConcern
  extend ActiveSupport::Concern

  included do
    validates_associated :api_particulier_token, if: :will_save_change_to_api_particulier_token?
    validate :api_particulier_token_not_expired, if: :will_save_change_to_api_particulier_token?
  end

  def api_particulier_token
    APIParticulierToken.new(self[:api_particulier_token])
  end

  def api_particulier_token?
    self[:api_particulier_token].present?
  end

  private

  def api_particulier_token_not_expired
    expires_at = api_particulier_token.expires_at
    return if expires_at.nil? || expires_at.future?

    errors.add(:api_particulier_token, :expired, date: I18n.l(expires_at.to_date, format: :long))
  end
end
