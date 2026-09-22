# frozen_string_literal: true

# These hooks run on every authenticated request: a bug here locks out everyone,
# ourselves included. Hence the rescue on each one, and the adoption of sessions
# older than the registry.

# Warden funnels three events through this single callback, and they split in
# two: two ways a session opens, one way it continues. Matching on the event
# rather than registering twice behind a filter -- a fourth event would then
# match neither and be dropped in silence, which is exactly how `sign_in` went
# unregistered for a while. Here it raises NoMatchingPatternError, lands in
# Sentry, and the request carries on.
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

  # :fetch -- the user was read back from the cookie, on every request after the
  #           one that signed them in. The session continues, so the row it names
  #           has to still be good.
  #
  # Log out rather than throw: this also fires on opportunistic fetches, like
  # `current_super_admin` in the layout, and one of them runs from an `ensure`
  # after the action. Emptying the scope lets whatever really needs it fail on
  # its own.
  in :fetch
    warden_session = warden.session(scope)
    session_id = warden_session[SessionRegistrableConcern::SESSION_KEY]

    if session_id.nil?
      SessionRegistrableConcern.open_session!(record, warden, scope)
    else
      user_session = UserSession.find_by(id: session_id, sessionable: record)

      # Rows written before roles had deadlines carry none, and nothing else
      # would ever give them one. Counted from `created_at`, not from now: a
      # deadline that restarts at the deploy is not the deadline.
      user_session&.backfill_expiry! { record.session_max_lifetime }

      if user_session.nil? || user_session.unusable?
        # In the Rack env, which Warden hands to the failure app unchanged: we
        # log out rather than throw, so there is no `throw(:warden, message:)`
        # to carry the reason. The env dies with the request, so a reason can
        # never resurface on a later one.
        warden.request.env[SessionRegistrableConcern::END_REASON_KEY] = (user_session&.unusable_reason || :session_revoked).to_s
        warden.logout(scope)
      end
    end
  end
rescue StandardError => e
  Sentry.capture_exception(e)
end

# Not gated on the feature: a row left alive by a sign out would make the session
# list lie, and closing one locks nobody out.
Warden::Manager.before_logout do |record, warden, options|
  next unless record.is_a?(SessionRegistrableConcern)

  session_id = SessionRegistrableConcern.warden_session(warden, options[:scope])[SessionRegistrableConcern::SESSION_KEY]
  next if session_id.nil?

  record.user_sessions.usable.where(id: session_id).revoke_all!(:sign_out)
rescue StandardError => e
  Sentry.capture_exception(e)
end
