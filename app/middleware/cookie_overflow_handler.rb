# frozen_string_literal: true

class CookieOverflowHandler
  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
  rescue ActionDispatch::Cookies::CookieOverflow => e
    request = Rack::Request.new(env)
    cookie_name = overflowing_cookie_name(e.message)

    Rails.logger.error(
      "[CookieOverflowHandler] CookieOverflow on #{request.request_method} #{request.path} | " \
      "message=#{e.message}"
    )

    headers = {
      "Location" => "/",
      "Content-Type" => "text/html",
      "Content-Length" => "0",
      "Set-Cookie" => clear_cookie_header(cookie_name),
    }.compact

    [302, headers, []]
  end

  private

  def overflowing_cookie_name(message)
    message[/\A(?<cookie_name>\S+) cookie overflowed/, :cookie_name]
  end

  def clear_cookie_header(cookie_name)
    return if cookie_name.blank?

    "#{cookie_name}=; path=/; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT"
  end
end
