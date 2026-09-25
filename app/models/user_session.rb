# frozen_string_literal: true

class UserSession < ApplicationRecord
  REVOCATION_REASONS = %w[sign_out logout_device logout_all support new_session password_change inactivity].freeze

  belongs_to :sessionable, polymorphic: true

  validates :revoked_reason, inclusion: { in: REVOCATION_REASONS }, allow_nil: true

  scope :usable, -> { where(revoked_at: nil, expires_at: [nil, Time.current..]) }

  # A calendar month counted on the Paris clock, the way Ruby counts it in
  # `open_user_session!` -- both write the same column, so they have to agree.
  # `created_at` is a naive UTC timestamp and Postgres runs in UTC, so a bare
  # `created_at + interval` keeps the UTC hour and lands an hour off across a DST
  # boundary. Hence the round trip: read as UTC, shift to Paris, add the months
  # there, come back to UTC.
  EXPIRY_FROM_CREATED_AT =
    "timezone('UTC', timezone(?, timezone(?, timezone('UTC', created_at)) + CAST(? AS interval)))"

  scope :expiring_later_than, -> (lifetime) do
    tz = Time.zone.tzinfo.name

    where("expires_at IS NULL OR expires_at > #{EXPIRY_FROM_CREATED_AT}", tz, tz, lifetime.iso8601)
  end

  # The one place that decides what a reason may be: a caller checking it again
  # before acting calls this rather than repeating the list.
  def self.validate_reason!(reason)
    raise ArgumentError, "unknown revocation reason #{reason.inspect}" unless REVOCATION_REASONS.include?(reason.to_s)
  end

  def self.revoke_all!(reason)
    # `.all`, `.where(nil)` and `.unscoped` all set a current_scope, so its mere
    # presence proves nothing: what matters is that the relation is filtered.
    raise ArgumentError, 'refusing to revoke every session at once: scope the relation first' if current_scope.nil? || current_scope.where_clause.empty?
    validate_reason!(reason)

    usable.update_all(revoked_at: Time.current, revoked_reason: reason.to_s, updated_at: Time.current)
  end

  # An ISO 8601 interval, never seconds: `1.month.to_i` is the average month, ten
  # hours longer than the calendar one the trusted device expires with.
  def self.expire_from_created_at!(lifetime)
    tz = Time.zone.tzinfo.name

    update_all(["expires_at = #{EXPIRY_FROM_CREATED_AT}, updated_at = ?", tz, tz, lifetime.iso8601, Time.current])
  end

  def unusable?
    revoked_at.present? || (expires_at.present? && expires_at.past?)
  end

  def unusable_reason
    return revoked_reason.presence&.to_sym || :session_revoked if revoked_at.present?

    :expired if expires_at.present? && expires_at.past?
  end
end
