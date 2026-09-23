# frozen_string_literal: true

class SessionFailureApp < Devise::FailureApp
  REDIRECT_HEADER = 'X-Sign-In-Path'

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
    if http_auth?
      remember_why! if @end_reason.present?

      return super
    end

    return super if !turbo_frame_request?

    request.flash[:alert] = i18n_message
    store_location!

    headers[REDIRECT_HEADER] = scope_url
    self.status = :unauthorized
    self.content_type = 'text/plain'
    self.response_body = ''
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

  # The frame URL is a modal fragment; what the user was looking at is the page
  # around it. Devise's GET-only rule does not apply: the destination is the
  # referer, a page the browser just rendered.
  def store_location!
    return super if !turbo_frame_request?

    location = page_around_the_frame

    # An unusable referer is no reason to store nothing: without this the sign
    # in lands on the root rather than where the person was.
    return super if location.blank?

    store_location_for(scope, location)
  end

  def page_around_the_frame
    uri = SameOriginUri.parse(request.referer, request)

    return if uri.nil? || uri.path.blank?

    [uri.path, uri.query].compact.join('?')
  end

  # Frames only, not every Turbo request: a form submission or a stream follows
  # a redirect perfectly well, and answering those with a 401 would put their
  # recovery in the hands of the JavaScript. A frame cannot -- the sign in page
  # would render inside it.
  def turbo_frame_request?
    request.headers['Turbo-Frame'].present?
  end
end
