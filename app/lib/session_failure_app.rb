# frozen_string_literal: true

class SessionFailureApp < Devise::FailureApp
  # Marks a flash that explains why a session ended, so the next failure keeps
  # it instead of writing the generic message over it.
  SESSION_ENDED_KEY = :session_ended

  def respond
    # Read once, and not again: the hook fires on opportunistic fetches too, so
    # a later unrelated failure in the same request must not inherit this.
    @end_reason = request.env.delete(SessionRegistrableConcern.end_reason_key(scope))

    return super if warden_options[:recall].present?

    # Neither lands on the sign in page right away: an XHR client throws the 401
    # body away and reloads, a frame shows the page only once Turbo loads it
    # whole. Other failures may come first, and by then the scope is logged out,
    # so none of them recomputes why. An ordinary page reads the flash at once.
    remember_why! if @end_reason.present? && (http_auth? || request.headers['Turbo-Frame'].present?)

    super
  end

  def i18n_message(default = nil)
    return super if warden_options[:recall].present? || @end_reason.blank?

    I18n.t(@end_reason, scope: [:devise, :failure], default: super)
  end

  private

  # The reason exists on the first rejected request only. Each later failure
  # would write the generic message over it, so it is marked, the way Devise
  # marks its own `:timedout` message.
  def remember_why!
    request.flash[:alert] = i18n_message
    request.flash[SESSION_ENDED_KEY] = true
  end

  # Marker and message are kept together, for as long as failures keep coming:
  # a page of frames fails once per frame. Each hop being itself a failure, the
  # explanation cannot outlive the trouble it explains -- the first page that
  # shows the flash consumes both.
  def redirect
    return super if !request.flash[SESSION_ENDED_KEY]

    request.flash.keep(:alert)
    request.flash.keep(SESSION_ENDED_KEY)
    store_location!
    redirect_to redirect_url
  end

  # Devise's GET-only rule does not apply to a frame: the destination is the
  # referer, a page the browser just rendered.
  def store_location!
    location = PageAroundTheFrame.location(request)

    # Not a frame, or an unusable referer -- which is no reason to store nothing:
    # without this the sign in lands on the root rather than where they were.
    return super if location.blank?

    store_location_for(scope, location)
  end
end
