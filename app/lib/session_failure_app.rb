# frozen_string_literal: true

class SessionFailureApp < Devise::FailureApp
  # Marks a flash that explains why a session ended, so the next failure keeps it.
  SESSION_ENDED_KEY = :session_ended

  def respond
    # Read once: the hook fires on opportunistic fetches too, and a later failure
    # must not inherit this.
    @end_reason = request.env.delete(SessionRegistrableConcern.end_reason_key(scope))

    return super if warden_options[:recall].present?

    # The client discards the 401 body, and by then nothing recomputes why: the
    # flash is all that reaches the page they land on.
    if http_auth?
      remember_why! if @end_reason.present? || request.flash[SESSION_ENDED_KEY]

      return super
    end

    return super if !turbo_frame_request?

    # Nothing to tell the client: it reloads, and the server answers that with the
    # right scope's sign in page.
    remember_why!

    self.status = :unauthorized
    self.content_type = 'text/plain'
    self.response_body = ''
  end

  def i18n_message(default = nil)
    return super if warden_options[:recall].present? || @end_reason.blank?

    I18n.t(@end_reason, scope: [:devise, :failure], default: super)
  end

  private

  # The reason exists on the first rejected request only, and every request that
  # follows is another failure that would write the generic message over it.
  # Marked and kept, the way Devise keeps its own `:timedout`, and written here
  # alone so the two branches cannot disagree.
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

  # Frames only: a stream follows a redirect, a frame cannot -- the sign in page
  # would render inside it. Any method, the recovery being a reload.
  def turbo_frame_request?
    request.headers['Turbo-Frame'].present?
  end
end
