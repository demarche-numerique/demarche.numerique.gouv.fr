# frozen_string_literal: true

# These hooks run on every authenticated request: a bug here locks out everyone,
# ourselves included. Hence the rescue on each one.

# Matched on the event rather than filtered: a fourth event would be dropped in
# silence, which is how `sign_in` went unregistered for a while. Here it raises
# NoMatchingPatternError and lands in Sentry.
Warden::Manager.after_set_user do |record, warden, options|
  next unless record.is_a?(SessionRegistrableConcern)
  next unless Flipper.enabled?(:session_registry, record)

  scope = options[:scope]

  case options[:event]
  # :set_user is how FranceConnect, ProConnect, invitations, confirmations and
  # expert links sign people in. Both open a session, so both write a row:
  # keying on :authentication alone -- what `after_authentication` does -- would
  # leave every one of those in a sign in loop.
  in :authentication | :set_user
    SessionRegistrableConcern.open_session!(record, warden, scope)

  # :fetch -- read back from the cookie on every later request, so the row it
  # names has to still be good. Logged out rather than thrown: this also fires
  # on opportunistic fetches, one of them from an `ensure` after the action.
  in :fetch
    warden_session = warden.session(scope)
    session_id = warden_session[SessionRegistrableConcern::SESSION_KEY]

    if session_id.nil?
      # Opened before the registry. Such sessions were adopted for a week after
      # every account was covered; one still arriving has been away all that time.
      warden.request.env[SessionRegistrableConcern::END_REASON_KEY] = 'expired'
      warden.logout(scope)
    else
      user_session = UserSession.find_by(id: session_id, sessionable: record)

      # The row first: a session both revoked and stale must say it was revoked,
      # which is the message the user needs.
      reason =
        if user_session.nil? || user_session.unusable?
          user_session&.unusable_reason || :session_revoked
        elsif SessionRegistrableConcern.inactive?(warden_session)
          :inactivity
        end

      if reason.present?
        # Before the logout: `before_logout` would otherwise find the row usable
        # and stamp it `sign_out`, as if the user had left on purpose.
        user_session&.usable_scope&.revoke_all!(:inactivity) if reason == :inactivity

        # In the Rack env, which Warden hands to the failure app unchanged: we
        # log out rather than throw, so there is no `throw(:warden, message:)`.
        warden.request.env[SessionRegistrableConcern::END_REASON_KEY] = reason.to_s
        warden.logout(scope)
      end
    end
  end
rescue StandardError => e
  Sentry.capture_exception(e)
end

# Not gated: "stay signed in" is not part of the registry, and gating it would
# take the persistent cookie away from everyone while the flag is off.
Warden::Manager.after_set_user do |record, warden, options|
  next unless record.is_a?(SessionRegistrableConcern)

  case options[:event]
  in :authentication | :set_user
    SessionRegistrableConcern.remember!(record, warden, options[:scope])
  in :fetch
    # Here rather than beside the check that reads it, because that check is
    # gated: closing the flag would let `last_seen_on` go stale, and opening it
    # again would sign every active user out at once.
    SessionRegistrableConcern.touch_last_seen!(SessionRegistrableConcern.warden_session(warden, options[:scope]))
    SessionRegistrableConcern.persist_cookie!(warden, options[:scope])
  end
rescue StandardError => e
  Sentry.capture_exception(e)
end

# Not gated: a row left alive by a sign out would make the session list lie.
Warden::Manager.before_logout do |record, warden, options|
  next unless record.is_a?(SessionRegistrableConcern)

  session_id = SessionRegistrableConcern.warden_session(warden, options[:scope])[SessionRegistrableConcern::SESSION_KEY]
  next if session_id.nil?

  record.user_sessions.usable.where(id: session_id).revoke_all!(:sign_out)
rescue StandardError => e
  Sentry.capture_exception(e)
end
