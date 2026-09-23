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

  # The raw user-agent and not a label: deriving it at display time means a
  # better parser later also improves old rows. The address is never rewritten
  # afterwards -- reading a row on every request must stay a read.
  def open_user_session!(user_agent, ip_address = nil)
    user_sessions.create!(
      user_agent: sanitized_user_agent(user_agent),
      ip_address:,
      expires_at: session_max_lifetime&.from_now
    )
  end

  # `except&.id`, not `except.present?`: an unsaved record has a nil id, and
  # `where.not(id: nil)` would revoke the very row we mean to spare.
  # Read afresh rather than `reload`: `has_one` assigns its target only after
  # save, so inside the `after_create` the owner still answers nil for the role
  # being granted -- from cache, since User eager loads its roles.
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

  # Client-controlled: invalid UTF-8 or a NUL makes Postgres refuse the INSERT,
  # the hook rescues it, and the session opens with no row -- exempt from every
  # deadline. Scrubbed rather than rejected.
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
