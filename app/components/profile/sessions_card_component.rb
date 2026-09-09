# frozen_string_literal: true

class Profile::SessionsCardComponent < ApplicationComponent
  private

  def render? = sessions.any?

  def sessions
    @sessions ||= current_user.user_sessions.usable.order(created_at: :desc).to_a
  end

  def current?(user_session) = user_session.id == Current.user_session&.id

  def device_label(user_session) = DeviceLabel.new(user_session.user_agent).to_s
end
