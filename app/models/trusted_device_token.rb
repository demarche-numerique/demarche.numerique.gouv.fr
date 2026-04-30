# frozen_string_literal: true

class TrustedDeviceToken < ApplicationRecord
  LOGIN_TOKEN_VALIDITY = 1.week
  LOGIN_TOKEN_YOUTH = 15.minutes

  belongs_to :instructeur, optional: false
  has_secure_token

  scope :expiring_in_one_week, -> do
    window_start = TrustedDeviceConcern::TRUSTED_DEVICE_PERIOD.ago
    window_end = (TrustedDeviceConcern::TRUSTED_DEVICE_PERIOD - 1.week).ago
    where(activated_at: window_start..window_end,
          renewal_notified_at: nil)
  end

  scope :renewal_not_needed, -> do
    not_expiring_soon = where(activated_at: (TrustedDeviceConcern::TRUSTED_DEVICE_PERIOD - 1.week).ago..)
    recently_notified = where(renewal_notified_at: 1.week.ago..)
    not_expiring_soon.or(recently_notified)
  end

  def token_valid?
    LOGIN_TOKEN_VALIDITY.ago < created_at
  end

  def token_valid_until
    created_at + LOGIN_TOKEN_VALIDITY
  end

  def token_young?
    LOGIN_TOKEN_YOUTH.ago < created_at
  end
end
