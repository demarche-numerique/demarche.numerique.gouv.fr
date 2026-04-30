# frozen_string_literal: true

# Temporary diagnostic middleware to investigate 406 errors on direct uploads.
# Positioned early in the Rack stack to capture the response regardless of origin.
# Remove once the root cause is identified.
class DirectUpload406Logger
  def initialize(app)
    @app = app
  end

  def call(env)
    original_path = env["PATH_INFO"]
    status, headers, response = @app.call(env)

    if status == 406 && original_path.include?("direct_uploads")
      request = Rack::Request.new(env)

      Sentry.capture_message("[DirectUpload406] 406 on direct_uploads", extra: {
        path: env["PATH_INFO"],
        method: env["REQUEST_METHOD"],
        accept: env["HTTP_ACCEPT"],
        content_type: env["CONTENT_TYPE"],
        user_agent: env["HTTP_USER_AGENT"]&.truncate(200),
        ip: request.ip,
        csrf_present: env["HTTP_X_CSRF_TOKEN"].present?,
        x_requested_with: env["HTTP_X_REQUESTED_WITH"],
        exception_class: env["action_dispatch.exception"]&.class&.name,
        exception_message: env["action_dispatch.exception"]&.message&.truncate(500),
      })
    end

    [status, headers, response]
  end
end
