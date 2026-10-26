# frozen_string_literal: true

class Users::ResendConfirmationButtonComponent < ApplicationComponent
  def initialize(seconds_remaining:)
    @seconds_remaining = seconds_remaining
  end

  private

  attr_reader :seconds_remaining

  def resend_label
    t('views.confirmation.new.resent')
  end

  def wrapper_data
    {
      controller: 'countdown-button',
      action: 'visibilitychange@document->countdown-button#refresh pageshow@window->countdown-button#restore',
      countdown_button_seconds_value: seconds_remaining,
      countdown_button_one_value: t('.countdown_one'),
      countdown_button_other_value: t('.countdown_other'),
      countdown_button_label_value: resend_label,
      countdown_button_available_value: t('.available'),
    }
  end
end
