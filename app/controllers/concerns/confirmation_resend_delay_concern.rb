# frozen_string_literal: true

module ConfirmationResendDelayConcern
  extend ActiveSupport::Concern

  RESEND_DELAY = 2.minutes

  private

  def remember_confirmation_request
    session[:confirmation_requested_at] = Time.current.to_i
  end
end
