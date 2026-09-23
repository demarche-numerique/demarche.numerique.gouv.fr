# frozen_string_literal: true

module SessionHelpers
  # Posts the real sign in form rather than reaching for Devise's `sign_in`:
  # only a winning strategy raises the :authentication event, and the user agent
  # a session is registered with comes from here.
  def post_user_session(user, password: users.default_password, remember_me: nil, user_agent: nil)
    credentials = { email: user.email, password: }
    credentials[:remember_me] = remember_me ? '1' : '0' if !remember_me.nil?

    post user_session_path,
      params: { user: credentials },
      headers: user_agent.present? ? { 'HTTP_USER_AGENT' => user_agent } : {}
  end
end

RSpec.configure do |config|
  config.include SessionHelpers, type: :request
end
