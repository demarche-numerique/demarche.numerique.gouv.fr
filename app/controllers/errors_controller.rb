# frozen_string_literal: true

class ErrorsController < ApplicationController
  rescue_from StandardError do |exception|
    Sentry.capture_exception(exception)
    # catch any error, except errors triggered by middlewares outside controller (like warden middleware)
    render file: Rails.public_path.join('500.html'), layout: false, status: :internal_server_error
  end

  def internal_server_error
    # This dynamic template is rendered when a "normal" error occurs, (ie. a bug which is 99.99% of errors.)
    # However if this action fails (error in the view or in a middlewares)
    # the exceptions are rescued and a basic 100% static html file is rendererd instead.
    render_error 500
  end

  def not_found = render_error 404

  def unprocessable_entity
    retry_url = csrf_retry_redirect_url

    if retry_url
      redirect_to retry_url
    else
      render_error 422
    end
  end

  def show # generic page for others errors
    @status = params[:status].to_i
    @error_name = Rack::Utils::HTTP_STATUS_CODES[@status]

    render_error @status
  end

  # Intercept errors in before_action when fetching user or roles
  # when db is unreachable so we can still display a nice 500 static page
  def current_user
    super
  rescue
    nil
  end

  def current_user_roles
    super
  rescue
    nil
  end

  private

  def render_error(status)
    respond_to do |format|
      format.html { render status: }
      format.json { render status:, json: { status:, name: Rack::Utils::HTTP_STATUS_CODES[status] } }
    end
  end

  # There's a subtle issue with using flash[:alert] here.
  # ErrorsController is mounted via `config.exceptions_app = self.routes`.
  # During the error-handling request flow the session and flash middlewares
  # (e.g. ActionDispatch::Session::CookieStore and ActionDispatch::Flash) are
  # bypassed, so the normal `flash` mechanism is not available. Do not rely on
  # `flash` in this controller; use the csrf_retry parameter instead which is catched by application controller
  def csrf_retry_redirect_url
    return if !user_signed_in?

    referer_uri = SameOriginUri.parse(request.referer, request)
    return if referer_uri.nil?

    params = Rack::Utils.parse_nested_query(referer_uri.query)
    return if params['csrf_retry'] == '1'

    params['csrf_retry'] = '1'
    referer_uri.query = params.to_query
    referer_uri.to_s
  end
end
