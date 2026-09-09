# frozen_string_literal: true

class SessionFailureApp < Devise::FailureApp
  TURBO_STREAM = 'text/vnd.turbo-stream.html'
  REDIRECT_HEADER = 'X-Sign-In-Path'

  def respond
    return super if warden_options[:recall].present?
    return super unless turbo?

    request.flash[:alert] = i18n_message
    store_location!

    headers[REDIRECT_HEADER] = scope_url
    self.status = :unauthorized
    self.content_type = 'text/plain'
    self.response_body = ''
  end

  def i18n_message(default = nil)
    reason = Current.session_end_reason if warden_options[:recall].blank?

    return super if reason.blank?

    I18n.t(reason, scope: [:devise, :failure], default: super)
  end

  private

  # Coming back to the frame URL would land on a modal fragment, alone on an
  # otherwise blank page. What the user was looking at is the page around it.
  #
  # Devise stores nothing unless the request is a GET, because the attempted
  # path is where it sends the user back. Here the destination is the referer,
  # a page the browser just rendered, so the verb of the frame request that
  # failed does not matter.
  def store_location!
    return super if request.headers['Turbo-Frame'].blank?

    location = page_around_the_frame

    store_location_for(scope, location) if location.present?
  end

  def page_around_the_frame
    uri = URI.parse(request.referer.to_s)

    return if uri.path.blank?
    return if uri.host.present? && uri.host != request.host

    [uri.path, uri.query].compact.join('?')
  rescue URI::InvalidURIError
    nil
  end

  def turbo?
    request.headers['Turbo-Frame'].present? ||
      request.headers['Accept'].to_s.include?(TURBO_STREAM)
  end
end
