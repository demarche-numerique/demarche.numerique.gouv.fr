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

  # Returns the id it just wrote, so the caller can publish it on Current.
  def self.open_session!(record, warden, scope)
    request = warden.request
    session = warden.session(scope)

    # The key is about to name a different session, so the one it names now is
    # over. Left alone, its row stays usable for as long as its deadline allows
    # and the account keeps advertising a device nobody is signed in on. Revoked
    # by id rather than through `record`: signing Bob in on Alice's browser --
    # an activation link, a password reset -- takes the key over from her.
    UserSession.where(id: session[SESSION_KEY]).revoke_all!(:sign_out) if session[SESSION_KEY].present?

    session[SESSION_KEY] = record.open_user_session!(request.user_agent, request.remote_ip).id
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

  # The id is generated database-side: an unsaved row has none, and
  # `where.not(id: nil)` would revoke the very session we mean to spare.
  #
  # `only:` closes a single device. It goes through here rather than straight to
  # the relation so that everything else a revocation must cut -- the remember
  # token above all -- happens for one device as it does for all of them.
  def revoke_sessions!(reason:, except: nil, only: nil)
    raise ArgumentError, 'cannot spare a session that is not persisted' if except && !except.persisted?
    raise ArgumentError, 'cannot revoke a session that is not persisted' if only && !only.persisted?

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
