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
      remember_why! if @end_reason.present? || request.flash[SESSION_ENDED_KEY]

      return super
    end

    return super if !frame_navigation?

    remember_why!
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
  # write the generic message over ours. Marked and kept, the way Devise keeps its
  # own `:timedout` message.
  #
  # The one place that writes it, so no branch can mark a message it explains or
  # overwrite one already marked. A page carrying several lazy frames fails once
  # per frame, so the explanation is kept for as long as failures keep coming --
  # each hop being another failure, it cannot outlive the trouble it explains.
  def remember_why!
    if request.flash[SESSION_ENDED_KEY] && @end_reason.blank?
      request.flash.keep(:alert)
      request.flash.keep(SESSION_ENDED_KEY)

      return
    end

    request.flash[:alert] = i18n_message
    request.flash[SESSION_ENDED_KEY] = true if @end_reason.present?
  end

  def redirect
    return super if !request.flash[SESSION_ENDED_KEY]

    remember_why!
    store_location!
    redirect_to redirect_url
  end

  # The frame URL is a modal fragment; what the user was looking at is the page
  # around it. Devise's GET-only rule does not apply: the destination is the
  # referer, a page the browser just rendered.
  def store_location!
    return super if !frame_request?

    location = page_around_the_frame

    # An unusable referer is no reason to store nothing: without this the sign
    # in lands on the root rather than where the person was.
    return super if location.blank?

    store_location_for(scope, location)
  end

  # The origin gate, and nothing more: `store_location_for` runs Devise's own
  # `extract_path_from_location` over what it is handed, which is where the path
  # belongs -- it collapses the leading slashes of a `//host` referer and keeps a
  # fragment, neither of which a path built here would.
  def page_around_the_frame
    uri = SameOriginUri.parse(request.referer, request)

    return if uri.nil? || uri.path.blank?

    uri.to_s
  end

  # Frames only, not every Turbo request: a stream or a form submission follows a
  # redirect perfectly well, and answering those with a 401 would put their
  # recovery in the hands of the JavaScript. A frame navigation cannot -- the sign
  # in page would render inside the frame.
  #
  # Hence the method, and not the header alone: Turbo sets `Turbo-Frame` on a form
  # submission targeted at a frame too.
  def frame_navigation?
    request.get? && frame_request?
  end

  # Anything Turbo routed through a frame, whatever its method. What the person
  # was looking at is the page around it, so this is what decides where they come
  # back to -- a POST included.
  def frame_request?
    request.headers['Turbo-Frame'].present?
  end
end
