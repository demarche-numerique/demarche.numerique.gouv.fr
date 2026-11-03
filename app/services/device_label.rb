# frozen_string_literal: true

class DeviceLabel
  BROWSERS = [
    [/Edg[eA]?\/|EdgiOS\//, 'Edge'],
    [/OPR\/|Opera/, 'Opera'],
    [/Firefox\/|FxiOS\//, 'Firefox'],
    [/Chrome\/|CriOS\//, 'Chrome'],
    [/Safari\//, 'Safari'],
  ].freeze

  PLATFORMS = [
    [/iPhone|iPad|iPod/, 'iOS'],
    [/Android/, 'Android'],
    [/Windows/, 'Windows'],
    [/Mac OS X|Macintosh/, 'macOS'],
    [/Linux/, 'Linux'],
  ].freeze

  def initialize(user_agent)
    @user_agent = user_agent.to_s
  end

  def to_s
    browser = match(BROWSERS)
    platform = match(PLATFORMS)

    if browser && platform
      I18n.t('device_label.browser_on_platform', browser:, platform:)
    else
      browser || platform || I18n.t('device_label.unknown')
    end
  end

  private

  def match(rules) = rules.find { |pattern, _| @user_agent.match?(pattern) }&.last
end
