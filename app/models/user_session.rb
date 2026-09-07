# frozen_string_literal: true

class UserSession < ApplicationRecord
  REVOCATION_REASONS = %w[sign_out logout_device logout_all support new_session password_change].freeze

  belongs_to :sessionable, polymorphic: true

  validates :revoked_reason, inclusion: { in: REVOCATION_REASONS }, allow_nil: true

  scope :usable, -> { where(revoked_at: nil, expires_at: [nil, Time.current..]) }

  def self.revoke_all!(reason)
    raise ArgumentError, 'refusing to revoke every session at once: scope the relation first' if current_scope.nil?
    raise ArgumentError, "unknown revocation reason #{reason.inspect}" unless REVOCATION_REASONS.include?(reason.to_s)

    usable.update_all(revoked_at: Time.current, revoked_reason: reason.to_s, updated_at: Time.current)
  end

  def unusable?
    revoked_at.present? || (expires_at.present? && expires_at.past?)
  end

  def unusable_reason
    return revoked_reason.presence&.to_sym || :session_revoked if revoked_at.present?

    :expired if expires_at.present? && expires_at.past?
  end
end
