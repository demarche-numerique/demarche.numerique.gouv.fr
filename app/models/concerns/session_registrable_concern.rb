# frozen_string_literal: true

module SessionRegistrableConcern
  extend ActiveSupport::Concern

  # Rack env key, namespaced like `warden.options` and `action_dispatch.*`. One
  # per scope: several scopes fail in one request, and the failure app must not
  # show an usager's reason on the super admin sign in page.
  END_REASON_KEY_PREFIX = 'ds.session_end_reason.'

  SESSION_KEY = 'user_session_id'
  USER_AGENT_MAX_LENGTH = 500

  def self.end_reason_key(scope) = "#{END_REASON_KEY_PREFIX}#{scope}"

  # Not `warden.session(scope)`: it checks `authenticated?`, which refetches the
  # user, which fires the fetch hook again. Infinite recursion.
  #
  # `||=` and not `||`: callers write into what they get back, and a fresh hash
  # would be dropped with the request.
  def self.warden_session(warden, scope)
    warden.raw_session["warden.user.#{scope}.session"] ||= {}
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
  # One UPDATE, no row loaded: this runs inside the `after_create` of a role, and
  # bulk promotions grant thousands of them.
  #
  # A session older than the new deadline gets one already past and is cut on its
  # next request. That is the intent: it predates the role and was never opened
  # for its data.
  def tighten_sessions!(deadline)
    user_sessions
      .usable
      .where('expires_at IS NULL OR expires_at > created_at + CAST(? AS interval)', deadline.iso8601)
      .expire_from_created_at!(deadline)
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
