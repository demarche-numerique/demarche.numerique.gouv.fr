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
  # names has to still be good.
  in :fetch
    SessionRegistrableConcern.continue_session!(record, warden, scope)
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
    # The hook above may have just logged this scope out, or died into its
    # rescue: stamping then would resurrect the key Warden deleted and refresh a
    # session that failed its check.
    next if SessionRegistrableConcern.signed_out?(warden, options[:scope])

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
