# frozen_string_literal: true

module SessionRegistrableConcern
  extend ActiveSupport::Concern

  SESSION_KEY = 'user_session_id'
  # Rack env key, namespaced like `warden.options` and `action_dispatch.*`.
  END_REASON_KEY = 'ds.session_end_reason'

  LAST_SEEN_KEY = 'last_seen_on'

  # The checkbox, remembered as a decision rather than read as a parameter: it
  # only exists on the sign in request, and the expiry has to be set again on
  # every response.
  PERSISTENT_KEY = 'persistent'

  # Frozen in the session at creation, like `expires_at` on the row: the policy
  # a session lives under is the one it was opened under. Recomputing it from
  # today's roles would drop the usager's inactivity bound the moment they are
  # invited as an expert, leaving them a year with no bound at all -- and would
  # cost a `gestionnaires` SELECT on every authenticated request.
  INACTIVITY_KEY = 'inactivity_window'

  # One duration for every role, and the same Devise gave `remember_for`. It
  # decides nothing: the row is checked on every request and cuts first for
  # anyone whose deadline is shorter.
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

    # The key is about to name a different session, so the one it names now is
    # over. Left alone, its row stays usable for as long as its deadline allows
    # and the account keeps advertising a device nobody is signed in on. Revoked
    # by id rather than through `record`: signing Bob in on Alice's browser --
    # an activation link, a password reset -- takes the key over from her.
    UserSession.where(id: session[SESSION_KEY]).revoke_all!(:sign_out) if session[SESSION_KEY].present?

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

  # "Stay signed in" is an expiry on the session cookie, so the browser keeps it
  # across a restart. It grants nothing on its own -- the row it names is still
  # checked on every request -- so every role may have one.
  def self.remember!(record, warden, scope)
    warden.session(scope)[PERSISTENT_KEY] = !!record.try(:remember_me)
    stamp_policy!(record, warden, scope)

    persist_cookie!(warden, scope)
  end

  # Rack recomputes `Time.now + expire_after` on every response, so the window
  # slides on its own -- but only as long as the option is there. Rails rewrites
  # the session cookie on every response (its ciphertext is random, so the jar
  # never sees it unchanged), and a rewrite carrying no expiry turns a
  # persistent cookie back into a session one.
  def self.persist_cookie!(warden, scope)
    return if !warden_session(warden, scope)[PERSISTENT_KEY]

    warden.request.session_options[:expire_after] = SESSION_COOKIE_LIFETIME
  end

  # On every request, not only at sign in: Rails rewrites the session cookie on
  # every response, and a rewrite carrying no expiry would turn it back into a
  # session cookie. The smallest wins -- one cookie carries every Warden scope.
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

  # Called by every override: a subclass that revokes more than rows must refuse
  # a bad call before touching anything irreversible.
  def validate_revocation!(reason:, except:, only: nil)
    raise ArgumentError, "unknown revocation reason #{reason.inspect}" unless UserSession::REVOCATION_REASONS.include?(reason.to_s)
    raise ArgumentError, 'cannot spare a session that is not persisted' if except && !except.persisted?
    raise ArgumentError, 'cannot revoke a session that is not persisted' if only && !only.persisted?
  end

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

  # The id is generated database-side: an unsaved row has none, and
  # `where.not(id: nil)` would revoke the very session we mean to spare.
  #
  # `only:` closes a single device. It goes through here rather than straight to
  # the relation so that everything else a revocation must cut happens for one
  # device as it does for all of them.
  def revoke_sessions!(reason:, except: nil, only: nil)
    validate_revocation!(reason:, except:, only:)

    scope = user_sessions
    scope = scope.where.not(id: except.id) if except
    scope = scope.where(id: only.id) if only
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
