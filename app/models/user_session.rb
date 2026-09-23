# frozen_string_literal: true

class UserSession < ApplicationRecord
  REVOCATION_REASONS = %w[sign_out logout_device logout_all support new_session password_change inactivity].freeze

  belongs_to :sessionable, polymorphic: true

  validates :revoked_reason, inclusion: { in: REVOCATION_REASONS }, allow_nil: true

  scope :usable, -> { where(revoked_at: nil, expires_at: [nil, Time.current..]) }

  # The one place that decides what a reason may be: a caller checking it again
  # before acting calls this rather than repeating the list.
  def self.validate_reason!(reason)
    raise ArgumentError, "unknown revocation reason #{reason.inspect}" unless REVOCATION_REASONS.include?(reason.to_s)
  end

  def self.revoke_all!(reason)
    raise ArgumentError, 'refusing to revoke every session at once: scope the relation first' if current_scope.nil?
    validate_reason!(reason)

    usable.update_all(revoked_at: Time.current, revoked_reason: reason.to_s, updated_at: Time.current)
  end

  # The deadline crosses into SQL as an ISO 8601 interval, never as seconds: a
  # month is a calendar month on both sides, where `1.month.to_i` is the average
  # one -- ten hours longer than the trusted device it expires with.
  def self.expire_from_created_at!(lifetime)
    update_all(['expires_at = created_at + CAST(? AS interval), updated_at = ?', lifetime.iso8601, Time.current])
  end

  def unusable?
    revoked_at.present? || (expires_at.present? && expires_at.past?)
  end

  def unusable_reason
    return revoked_reason.presence&.to_sym || :session_revoked if revoked_at.present?

    :expired if expires_at.present? && expires_at.past?
  end
end
