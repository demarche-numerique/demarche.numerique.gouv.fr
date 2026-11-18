# frozen_string_literal: true

class Profile::SessionsCardComponent < ApplicationComponent
  private

  def render? = sessions.any?

  def sessions
    @sessions ||= current_user.user_sessions.usable.order(created_at: :desc).to_a
  end

  def current?(user_session) = user_session.id == Current.user_session&.id

  def device_label(user_session)
    browser = user_session.browser
    name = browser.name if browser.known?
    platform = platform_name(browser.platform)

    if name && platform
      t('.browser_on_platform', browser: name, platform:)
    else
      name || platform || t('.unknown_device')
    end
  end

  # The gem says "Generic Linux".
  def platform_name(platform)
    return if platform.unknown?

    platform.linux? ? 'Linux' : platform.name
  end
end
