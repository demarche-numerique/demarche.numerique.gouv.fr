# frozen_string_literal: true

class Users::ResendConfirmationButtonComponent < ApplicationComponent
  def initialize(seconds_remaining:)
    @seconds_remaining = seconds_remaining
  end

  private

  attr_reader :seconds_remaining

  def wrapper_data
    {
      controller: 'countdown-button',
      action: 'visibilitychange@document->countdown-button#refresh pageshow@window->countdown-button#restore',
      countdown_button_seconds_value: seconds_remaining,
      countdown_button_counter_one_value: t('.counter_one'),
      countdown_button_counter_other_value: t('.counter_other'),
      countdown_button_announcement_one_value: t('.announcement_one'),
      countdown_button_announcement_other_value: t('.announcement_other'),
      countdown_button_available_value: t('.available'),
    }
  end
end
