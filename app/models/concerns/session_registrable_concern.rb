# frozen_string_literal: true

module SessionRegistrableConcern
  extend ActiveSupport::Concern

  SESSION_KEY = 'user_session_id'
  # Rack env key, namespaced like `warden.options` and `action_dispatch.*`.
  END_REASON_KEY = 'ds.session_end_reason'

  LAST_SEEN_KEY = 'last_seen_on'

  # Frozen in the session at creation, like `expires_at` on the row: the policy
  # a session lives under is the one it was opened under. Recomputing it from
  # today's roles would drop the usager's inactivity bound the moment they are
  # invited as an expert, leaving them a year with no bound at all -- and would
  # cost a `gestionnaires` SELECT on every authenticated request.
  INACTIVITY_KEY = 'inactivity_window'
  USER_AGENT_MAX_LENGTH = 500

  # Not `warden.session(scope)`: it checks `authenticated?`, which refetches the
  # user, which fires the fetch hook again. Infinite recursion.
  def self.warden_session(warden, scope)
    warden.raw_session["warden.user.#{scope}.session"] || {}
  end

  def self.open_session!(record, warden, scope)
    request = warden.request
    session = warden.session(scope)

    session[LAST_SEEN_KEY] = Date.current.iso8601

    session[SESSION_KEY] = record.open_user_session!(request.user_agent, request.remote_ip).id
  end

  # The policy a session lives under is the one it was opened under, so it is
  # written once and never recomputed. The guard is what adopts a session opened
  # before this shipped: its first request stamps it, and no request after that
  # reads the model for it again.
  # Reads the raw hash rather than `warden.session`, which raises once a scope
  # has been logged out -- which is exactly what the hook above may have just
  # done when the session turned out to be revoked or stale.
  def self.stamp_policy!(record, warden, scope)
    session = warden.raw_session["warden.user.#{scope}.session"]
    return if session.nil?

    session[INACTIVITY_KEY] = record.session_inactivity_window&.to_i unless session.key?(INACTIVITY_KEY)
  end

  # Inactivity is read from the cookie, which is signed: the client cannot push
  # the date forward. A date and not an instant -- the window is counted in
  # weeks, the right day is precise enough.
  def self.inactive?(session)
    window = session[INACTIVITY_KEY]
    return false if window.blank?

    # No stamp means a session older than this code: adopt it, the request that
    # adopts it stamps it.
    last_seen = session[LAST_SEEN_KEY]
    return false if last_seen.blank?

    Date.parse(last_seen) < window.seconds.ago.to_date
  rescue Date::Error
    false
  end

  def self.touch_last_seen!(session)
    return if session[INACTIVITY_KEY].blank?

    today = Date.current.iso8601

    session[LAST_SEEN_KEY] = today if session[LAST_SEEN_KEY] != today
  end

  included do
    has_many :user_sessions, as: :sessionable, dependent: :delete_all

    # Here rather than on User: SuperAdmin is `:recoverable` too, and its reset
    # path is Devise's own controller, so a callback on User would leave the
    # most privileged account the only one whose sessions survive a password
    # change.
    after_update :revoke_sessions_after_password_change, if: :saved_change_to_encrypted_password?
  end

  # Every session goes, the current one included. Devise's reset path refuses a
  # signed in visitor (`require_no_authentication`), so in practice there is no
  # session to spare; when a signed in change of password ships, sparing it is
  # that feature's business.
  def revoke_sessions_after_password_change
    revoke_sessions!(reason: :password_change)
  end

  def session_max_lifetime = nil

  # nil means no sliding window: an absolute deadline bounds the account instead,
  # and the two strategies are exclusive.
  def session_inactivity_window = nil

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

  # The id is generated database-side: an unsaved row has none, and
  # `where.not(id: nil)` would revoke the very session we mean to spare.
  def revoke_sessions!(reason:, except: nil)
    raise ArgumentError, 'cannot spare a session that is not persisted' if except && !except.persisted?

    scope = user_sessions
    scope = scope.where.not(id: except.id) if except
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
