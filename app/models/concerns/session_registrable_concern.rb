# frozen_string_literal: true

module SessionRegistrableConcern
  extend ActiveSupport::Concern

  # Rack env key, namespaced like `warden.options` and `action_dispatch.*`.
  END_REASON_KEY = 'ds.session_end_reason'

  SESSION_KEY = 'user_session_id'
  USER_AGENT_MAX_LENGTH = 500

  # Not `warden.session(scope)`: it checks `authenticated?`, which refetches the
  # user, which fires the fetch hook again. Infinite recursion.
  def self.warden_session(warden, scope)
    warden.raw_session["warden.user.#{scope}.session"] || {}
  end

  def self.open_session!(record, warden, scope)
    request = warden.request

    warden.session(scope)[SESSION_KEY] = record.open_user_session!(request.user_agent, request.remote_ip).id
  end

  included do
    has_many :user_sessions, as: :sessionable, dependent: :delete_all
  end

  def session_max_lifetime = nil

  # The raw user-agent is stored, not a label: deriving it at display time means
  # a better parser later also improves existing rows.
  #
  # The address is the one the session was opened from, and it is never rewritten
  # afterwards: reading a row on every request must stay a read. What it is for is
  # spotting a session that was opened from somewhere unexpected.
  def open_user_session!(user_agent, ip_address = nil)
    user_sessions.create!(
      user_agent: sanitized_user_agent(user_agent),
      ip_address:,
      expires_at: session_max_lifetime&.from_now
    )
  end

  # `except&.id`, not `except.present?`: an unsaved record has a nil id, and
  # `where.not(id: nil)` would revoke the very row we mean to spare.
  # A role granted mid-session must not leave the session living under the year
  # an usager gets. Only ever shortens.
  #
  # Read afresh rather than `reload`: `has_one` assigns its target only after the
  # record is saved, so inside the `after_create` that brings us here the owner
  # still answers `nil` for the very role being granted -- and answers it from
  # cache, without a query, since User eager loads its roles. Reloading `self`
  # would reset associations the caller is still holding.
  #
  # A session already older than the new role's deadline ends at the next
  # request. That is the deadline doing its job, but it does mean a promotion
  # can sign someone out.
  def tighten_sessions!
    deadline = self.class.find(id).session_max_lifetime
    return if deadline.nil?

    user_sessions.usable.find_each do |session|
      tightened = session.created_at + deadline
      next if session.expires_at.present? && session.expires_at <= tightened

      session.update_column(:expires_at, tightened)
    end
  end

  def revoke_sessions!(reason:, except: nil)
    scope = user_sessions
    scope = scope.where.not(id: except.id) if except&.id
    scope.revoke_all!(reason)
  end

  private

  # A header, so entirely client-controlled. Bytes that are not valid UTF-8, or
  # a NUL, make Postgres refuse the INSERT -- and the hook rescues that, so the
  # session would open with no row at all: exempt from every deadline and from
  # revocation, on one crafted header. Scrubbed rather than rejected, because
  # nothing here is worth signing someone out over.
  def sanitized_user_agent(user_agent)
    return if user_agent.nil?

    user_agent
      .dup
      .force_encoding(Encoding::UTF_8)
      .scrub('')
      .delete("\u0000")
      .truncate(USER_AGENT_MAX_LENGTH)
  end
end
