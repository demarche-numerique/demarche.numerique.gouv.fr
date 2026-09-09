# frozen_string_literal: true

class Profile::SessionsCardComponent < ApplicationComponent
  # Passed in: the row this request runs under is named by the session cookie,
  # which the controller has and the component does not.
  def initialize(current_user_session: nil)
    @current_user_session = current_user_session
  end

  private

  # Rows outlive a rollback: with the registry closed nothing enforces them, so
  # the buttons would report closing a device that stays signed in. An empty
  # list is hidden too -- it reads as "signed in nowhere" to someone reading it.
  def render? = Flipper.enabled?(:session_registry, current_user) && sessions.any?

  def sessions
    @sessions ||= current_user.user_sessions.usable.order(created_at: :desc).to_a
  end

  def current?(user_session) = user_session.id == @current_user_session&.id

  def device_label(user_session) = DeviceLabel.new(user_session.user_agent).to_s
end
