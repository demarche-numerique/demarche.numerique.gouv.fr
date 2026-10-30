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

    # Devise's 401 body goes to a client that reloads and discards it -- and by
    # then the scope is logged out, so no later request recomputes why. The
    # flash is the only thing that reaches the page they land on.
    remember_why! if http_auth? && @end_reason.present?

    super
  end

  def i18n_message(default = nil)
    return super if warden_options[:recall].present? || @end_reason.blank?

    I18n.t(@end_reason, scope: [:devise, :failure], default: super)
  end

  private

  # The reason exists on the first rejected request only: the scope is logged
  # out by then, so nothing recomputes it. The client that gets this 401 throws
  # the body away and reloads, and that reload is another failure -- which would
  # write the generic message over ours. Marked and kept for one more hop, the
  # way Devise keeps its own `:timedout` message.
  def remember_why!
    request.flash[:alert] = i18n_message
    request.flash[SESSION_ENDED_KEY] = true
  end

  # The marker is not kept, so the message survives exactly one hop.
  def redirect
    return super if !request.flash[SESSION_ENDED_KEY]

    request.flash.keep(:alert)
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
