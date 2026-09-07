# frozen_string_literal: true

module SessionRegistrableConcern
  extend ActiveSupport::Concern

  SESSION_KEY = 'user_session_id'
  USER_AGENT_MAX_LENGTH = 500

  # Not `warden.session(scope)`: it checks `authenticated?`, which refetches the
  # user, which fires the fetch hook again. Infinite recursion.
  def self.warden_session(warden, scope)
    warden.raw_session["warden.user.#{scope}.session"] || {}
  end

  def self.open_session!(record, warden, scope)
    warden.session(scope)[SESSION_KEY] = record.open_user_session!(warden.request.user_agent).id
  end

  included do
    has_many :user_sessions, as: :sessionable, dependent: :delete_all
  end

  def session_max_lifetime = nil

  # The raw user-agent is stored, not a label: deriving it at display time means
  # a better parser later also improves existing rows.
  def open_user_session!(user_agent)
    user_sessions.create!(user_agent: sanitized_user_agent(user_agent), expires_at: session_max_lifetime&.from_now)
  end

  # `except&.id`, not `except.present?`: an unsaved record has a nil id, and
  # `where.not(id: nil)` would revoke the very row we mean to spare.
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
