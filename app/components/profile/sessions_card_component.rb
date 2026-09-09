# frozen_string_literal: true

class Profile::SessionsCardComponent < ApplicationComponent
  private

  # Gated on the feature, not just on having rows. Rows outlive a rollback: with
  # the registry closed nothing enforces them, so the buttons would report
  # closing a device that stays signed in, and no row would be marked current.
  #
  # An empty list is hidden too -- it would read as "you are signed in nowhere"
  # to someone who is, by definition, reading the page.
  def render? = Flipper.enabled?(:session_registry, current_user) && sessions.any?

  def sessions
    @sessions ||= current_user.user_sessions.usable.order(created_at: :desc).to_a
  end

  def current?(user_session) = user_session.id == Current.user_session_id

  def device_label(user_session) = DeviceLabel.new(user_session.user_agent).to_s
end
