# frozen_string_literal: true

module SessionRegistrableConcern
  extend ActiveSupport::Concern

  SESSION_KEY = 'user_session_id'

  # Rack env key, namespaced like `warden.options` and `action_dispatch.*`. One
  # per scope: several scopes fail in one request, and the failure app must not
  # show an usager's reason on the super admin sign in page.
  END_REASON_KEY_PREFIX = 'ds.session_end_reason.'

  # Where the cookie kept the last visit and "stay signed in" before the row did.
  # Read only to move them over: unused once every cookie that carried them has
  # been away longer than the inactivity window.
  LAST_SEEN_KEY = 'last_seen_on'
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

  # One transaction, the cookie after it: a failed INSERT leaves the session it
  # was replacing as it was, not revoked with the cookie still naming it.
  def self.open_session!(record, warden, scope, login_method: nil, france_connect_information: nil, continuing: nil)
    user_agent, remote_ip = warden.request.user_agent, warden.request.remote_ip
    outgoing = warden.session(scope)[SESSION_KEY]

    # in db
    user_session = record.transaction do
      drop_former_session!(outgoing)

      record.open_user_session!(user_agent, remote_ip, login_method:, france_connect_information:, continuing:, persistent: stays_signed_in?(record, outgoing))
    end

    # in cookie
    warden.session(scope)[SESSION_KEY] = user_session.id
    persist_cookie!(warden, user_session)

    # in current request, the usager's only: the same request loads the super admin too
    Current.user_session = user_session if scope == :user
  end

  # The usager's session going on under another login method, with nothing proven
  # again: the current row is revoked for a new one that continues it, and there
  # is no sign in for Devise to track.
  def self.swap_session!(user, warden, login_method:, reason:)
    continuing = Current.user_session

    user.transaction do
      user.user_sessions.where(id: continuing.id).revoke_all!(reason)
      open_session!(user, warden, :user, login_method:, continuing:)
    end
  end

  # By id: the key being taken over may name another account's session.
  def self.drop_former_session!(session_id)
    UserSession.where(id: session_id).revoke_all!(:new_session) if session_id.present?
  end

  # "Stay signed in" is an expiry on the session cookie, granting nothing on its
  # own. Said on the sign in form only: a programmatic `sign_in` leaves the
  # accessor nil, and keeps the choice of the session it replaces -- when that
  # session is the account's own.
  def self.stays_signed_in?(record, outgoing)
    remember_me = record.try(:remember_me)
    return remember_me if !remember_me.nil?

    outgoing.present? && record.user_sessions.exists?(id: outgoing, persistent: true)
  end

  # Rails rewrites the session cookie on every response (random ciphertext), and
  # a rewrite carrying no expiry turns a persistent cookie back into a session
  # one -- so the option has to be set again every time.
  def self.persist_cookie!(warden, user_session)
    return if !user_session.persistent?

    warden.request.session_options[:expire_after] = SESSION_COOKIE_LIFETIME
  end

  def self.move_cookie_stamps!(user_session, session)
    stamps = {
      persistent: session.delete(PERSISTENT_KEY),
      last_seen_on: session.delete(LAST_SEEN_KEY),
    }.compact

    user_session.update_columns(stamps) if stamps.any?
  end

  # Read back from the cookie on every later request, so the row it names has to
  # still be good. Logged out rather than thrown: this also fires on
  # opportunistic fetches, one of them from an `ensure` after the action.
  def self.continue_session!(record, warden, scope)
    session = warden.session(scope)
    session_id = session[SESSION_KEY]

    user_session = UserSession.find_by(id: session_id, sessionable: record) if session_id.present?
    move_cookie_stamps!(user_session, session) if user_session

    # The row first: a session both revoked and stale must say it was revoked,
    # which is the message the user needs.
    reason =
      if session_id.nil?
        # Opened before the registry. Such sessions were adopted for a week after
        # every account was covered; one still arriving has been away all that time.
        :expired
      elsif user_session.nil? || user_session.unusable?
        user_session&.unusable_reason || :session_revoked
      elsif user_session.inactive?
        :inactivity
      end

    if reason.nil?
      user_session.touch_last_seen!
      persist_cookie!(warden, user_session)
      Current.user_session = user_session if scope == :user
      return
    end

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
  # afterwards.
  #
  # A row `continuing:` another one keeps its start and deadline, which the role
  # deadlines are counted from.
  def open_user_session!(user_agent, ip_address = nil, login_method: nil, france_connect_information: nil, continuing: nil, persistent: false)
    user_sessions.create!(
      user_agent: sanitized_user_agent(user_agent),
      ip_address:,
      login_method:,
      france_connect_information:,
      persistent:,
      last_seen_on: Date.current,
      created_at: continuing&.created_at,
      expires_at: continuing ? continuing.expires_at : session_max_lifetime&.from_now
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
  #
  # `only:` goes through here rather than straight to the relation, so closing one
  # device still does everything else a revocation must do.
  def revoke_sessions!(reason:, except: nil, only: nil)
    UserSession.validate_reason!(reason)
    raise ArgumentError, 'cannot spare a session that is not persisted' if except && !except.persisted?
    raise ArgumentError, 'cannot revoke a session that is not persisted' if only && !only.persisted?
    raise ArgumentError, 'cannot combine except: and only:' if except && only

    transaction do
      revoke_account_wide!(reason)

      scope = user_sessions
      scope = scope.where.not(id: except.id) if except
      scope = scope.where(id: only.id) if only
      scope.revoke_all!(reason)
    end
  end

  private

  # What a sessionable cuts beyond its own rows. Nothing, unless it overrides.
  def revoke_account_wide!(reason) = nil

  # Client-controlled: invalid UTF-8 or a NUL makes Postgres refuse the INSERT,
  # and the sign in fails on one header. Scrubbed rather than rejected.
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
