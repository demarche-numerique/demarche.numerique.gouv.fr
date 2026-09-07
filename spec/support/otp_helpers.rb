# frozen_string_literal: true

module OtpHelpers
  def current_otp_for(super_admin)
    ROTP::TOTP.new(super_admin.otp_secret).now
  end

  # Posts the real sign in form, OTP step included, rather than reaching for
  # Devise's `sign_in`: only a winning strategy raises the :authentication
  # event, and the user agent a session is registered with comes from here.
  def post_super_admin_session(super_admin, user_agent: nil, remember_me: false)
    post super_admin_session_path,
      params: { super_admin: { email: super_admin.email, password: super_admin.password, otp_attempt: current_otp_for(super_admin), remember_me: } },
      headers: user_agent.present? ? { 'HTTP_USER_AGENT' => user_agent } : {}
  end
end

RSpec.configure do |config|
  config.include OtpHelpers, type: :controller
  config.include OtpHelpers, type: :request
end
