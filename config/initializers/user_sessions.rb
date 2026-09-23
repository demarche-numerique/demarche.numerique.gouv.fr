# frozen_string_literal: true

# These hooks run on every authenticated request: a bug here locks out everyone,
# ourselves included. Hence the rescue on each one, and the adoption of sessions
# older than the registry.

# Matched on the event rather than filtered: a fourth event would be dropped in
# silence, which is how `sign_in` went unregistered for a while. Here it raises
# NoMatchingPatternError and lands in Sentry.
Warden::Manager.after_set_user do |record, warden, options|
  next unless record.is_a?(SessionRegistrableConcern)
  next unless Flipper.enabled?(:session_registry, record)

  scope = options[:scope]

  case options[:event]
  # :authentication -- a strategy won, which here means the sign in form, OTP
  #                    step included.
  # :set_user       -- application code called Devise's `sign_in`. That is how
  #                    FranceConnect, ProConnect, invitations, email confirmation,
  #                    password resets and expert links all sign people in.
  #
  # Both mean a session opens, so both write its row. Keying on :authentication
  # alone -- what `after_authentication` does -- would leave every path on the
  # second line without one: invisible while sessions without a row are still
  # adopted, a sign in loop the moment they no longer are.
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
