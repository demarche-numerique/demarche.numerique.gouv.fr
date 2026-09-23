# frozen_string_literal: true

module SessionRegistrableConcern
  extend ActiveSupport::Concern

  SESSION_KEY = 'user_session_id'

  # Rack env key, namespaced like `warden.options` and `action_dispatch.*`. One
  # per scope: several scopes fail in one request, and the failure app must not
  # show an usager's reason on the super admin sign in page.
  END_REASON_KEY_PREFIX = 'ds.session_end_reason.'

  LAST_SEEN_KEY = 'last_seen_on'

  # A decision, not a parameter: the checkbox only exists on the sign in
  # request, and the expiry has to be set again on every response.
  PERSISTENT_KEY = 'persistent'

  # The same for every role, and not the only bound: a shorter absolute
  # deadline cuts first.
  INACTIVITY_WINDOW = 2.weeks

  # The window plus a day, because `inactive?` compares whole dates: a session
  # last seen on D is still fresh until the end of D + 14, while a cookie of
  # exactly 14 days dies at the hour. The cookie has to outlast the check, never
  # the other way round.
  SESSION_COOKIE_LIFETIME = INACTIVITY_WINDOW + 1.day

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
    session = warden.session(scope)

    session[LAST_SEEN_KEY] = Date.current.iso8601

    session[SESSION_KEY] = record.open_user_session!(request.user_agent, request.remote_ip).id
  end

  # Read from the signed cookie, so the client cannot push the date forward.
  # A date and not an instant: the window is counted in weeks.
  def self.inactive?(session)
    # No stamp means a session older than this code: adopt it, the request that
    # adopts it stamps it.
    last_seen = session[LAST_SEEN_KEY]
    return false if last_seen.blank?

    Date.parse(last_seen) < INACTIVITY_WINDOW.ago.to_date
  rescue Date::Error
    false
  end

  # "Stay signed in" is an expiry on the session cookie, granting nothing on its
  # own. Written only when someone said something: a programmatic `sign_in`
  # leaves the accessor nil, and must not silently take the choice back.
  def self.remember!(record, warden, scope)
    remember_me = record.try(:remember_me)

    warden.session(scope)[PERSISTENT_KEY] = !!remember_me if !remember_me.nil?

    persist_cookie!(warden, scope)
  end

  # Rails rewrites the session cookie on every response (random ciphertext), and
  # a rewrite carrying no expiry turns a persistent cookie back into a session
  # one -- so the option has to be set again every time.
  def self.persist_cookie!(warden, scope)
    return if !warden_session(warden, scope)[PERSISTENT_KEY]

    warden.request.session_options[:expire_after] = SESSION_COOKIE_LIFETIME
  end

  # Written only when the day turns, so the cookie is left alone the rest of
  # the time.
  def self.touch_last_seen!(session)
    today = Date.current.iso8601

    session[LAST_SEEN_KEY] = today if session[LAST_SEEN_KEY] != today
  end

  # Whether `continue_session!` -- or its rescue -- has just dropped this scope.
  def self.signed_out?(warden, scope)
    warden.raw_session["warden.user.#{scope}.key"].nil?
  end

  # Read back from the cookie on every later request, so the row it names has to
  # still be good. Logged out rather than thrown: this also fires on
  # opportunistic fetches, one of them from an `ensure` after the action.
  def self.continue_session!(record, warden, scope)
    session = warden.session(scope)
    session_id = session[SESSION_KEY]

    return open_session!(record, warden, scope) if session_id.nil?

    user_session = UserSession.find_by(id: session_id, sessionable: record)

    # The row first: a session both revoked and stale must say it was revoked,
    # which is the message the user needs.
    reason =
      if user_session.nil? || user_session.unusable?
        user_session&.unusable_reason || :session_revoked
      elsif inactive?(session)
        :inactivity
      end

    return if reason.nil?

    # Before the logout: `before_logout` would otherwise find the row usable and
    # stamp it `sign_out`, as if the user had left on purpose.
    record.user_sessions.usable.where(id: session_id).revoke_all!(reason) if reason == :inactivity

    # In the Rack env, which Warden hands to the failure app unchanged: we log
    # out rather than throw, so there is no `throw(:warden, message:)`.
    warden.request.env[end_reason_key(scope)] = reason.to_s
    warden.logout(scope)
  end

  included do
    has_many :user_sessions, as: :sessionable, dependent: :delete_all

    # Here rather than on User: SuperAdmin is `:recoverable` too, and would
    # otherwise be the only account whose sessions survive.
    after_update :revoke_sessions_after_password_change, if: :saved_change_to_encrypted_password?
  end

  # The current session included: there is no request here to spare it from.
  # A controller that signs the person in right after has to pass `force: true`,
  # or Devise leaves them on the row this just revoked.
  def revoke_sessions_after_password_change
    revoke_sessions!(reason: :password_change)
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

  # One UPDATE, no row loaded: this runs inside the `after_create` of a role, and
  # bulk promotions grant thousands of them.
  #
  # A session older than the new deadline gets one already past and is cut on its
  # next request. That is the intent: it predates the role and was never opened
  # for its data.
  def tighten_sessions!(deadline)
    user_sessions
      .usable
      .expiring_later_than(deadline)
      .expire_from_created_at!(deadline)
  end

  # The guards run before anything irreversible: `except` with a nil id would
  # turn into `where.not(id: nil)` and revoke every row, the one to spare first.
  # Then the account-wide steps, so a failure on the rows cannot leave an account
  # half signed out.
  def revoke_sessions!(reason:, except: nil)
    UserSession.validate_reason!(reason)
    raise ArgumentError, 'cannot spare a session that is not persisted' if except && !except.persisted?

    transaction do
      revoke_account_wide!(reason)

      scope = except ? user_sessions.where.not(id: except.id) : user_sessions
      scope.revoke_all!(reason)
    end
  end

  private

  # What a sessionable cuts beyond its own rows. Nothing, unless it overrides.
  def revoke_account_wide!(reason) = nil

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
