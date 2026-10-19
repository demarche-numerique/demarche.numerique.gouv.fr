# frozen_string_literal: true

module ConfirmationResendDelayConcern
  extend ActiveSupport::Concern

  RESEND_DELAY = 2.minutes

  included do
    helper_method :seconds_before_confirmation_resend
  end

  private

  def remember_confirmation_request
    session[:confirmation_requested_at] = Time.current.to_i
  end

  def seconds_before_confirmation_resend
    requested_at = session[:confirmation_requested_at]
    return 0 if requested_at.nil?

    (requested_at + RESEND_DELAY.to_i - Time.current.to_i).clamp(0, RESEND_DELAY.to_i)
  end
end
