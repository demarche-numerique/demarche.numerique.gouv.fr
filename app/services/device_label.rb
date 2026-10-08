# frozen_string_literal: true

# A coarse "Chrome on macOS", to help someone recognise their own device in a
# list. Never a fingerprint: the string is sent by the client and may lie.
# Derived at display time, so sharpening these rules also improves old rows.
class DeviceLabel
  # Most specific first: Edge and Chrome both claim to be Safari, Edge also
  # claims to be Chrome. On iOS every browser is Safari underneath, and only a
  # CriOS/FxiOS/EdgiOS token tells them apart.
  BROWSERS = [
    [/Edg[eA]?\/|EdgiOS\//, 'Edge'],
    [/OPR\/|Opera/, 'Opera'],
    [/Firefox\/|FxiOS\//, 'Firefox'],
    [/Chrome\/|CriOS\//, 'Chrome'],
    [/Safari\//, 'Safari'],
  ].freeze

  # iOS before macOS: an iPhone user-agent contains "like Mac OS X".
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
