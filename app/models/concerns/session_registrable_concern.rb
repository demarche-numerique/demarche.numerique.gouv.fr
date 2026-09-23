# frozen_string_literal: true

module SessionRegistrableConcern
  extend ActiveSupport::Concern

  SESSION_KEY = 'user_session_id'
  # Rack env key, namespaced like `warden.options` and `action_dispatch.*`.
  END_REASON_KEY = 'ds.session_end_reason'

  LAST_SEEN_KEY = 'last_seen_on'

  # A decision, not a parameter: the checkbox only exists on the sign in
  # request, and the expiry has to be set again on every response.
  PERSISTENT_KEY = 'persistent'

  # The same for every role, and not the only bound: a shorter absolute
  # deadline cuts first.
  INACTIVITY_WINDOW = 2.weeks

  # One duration for every role, the one `remember_for` had. It decides
  # nothing: the row is still checked on every request.
  SESSION_COOKIE_LIFETIME = 2.weeks

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

  # "Stay signed in" is an expiry on the session cookie. It grants nothing on
  # its own -- the row it names is still checked -- so every role may have one.
  def self.remember!(record, warden, scope)
    warden.session(scope)[PERSISTENT_KEY] = !!record.try(:remember_me)

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

  included do
    has_many :user_sessions, as: :sessionable, dependent: :delete_all

    # Here rather than on User: SuperAdmin is `:recoverable` too, and would
    # otherwise be the only account whose sessions survive.
    after_update :revoke_sessions_after_password_change, if: :saved_change_to_encrypted_password?
  end

  # The current session included: Devise's reset path refuses a signed in
  # visitor (`require_no_authentication`), so there is none to spare.
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

  # Called by every override: a subclass that revokes more than rows must refuse
  # a bad call before touching anything irreversible.
  def validate_revocation!(reason:, except:)
    raise ArgumentError, "unknown revocation reason #{reason.inspect}" unless UserSession::REVOCATION_REASONS.include?(reason.to_s)
    raise ArgumentError, 'cannot spare a session that is not persisted' if except && !except.persisted?
  end

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
    validate_revocation!(reason:, except:)

    scope = user_sessions
    scope = scope.where.not(id: except.id) if except
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
