# frozen_string_literal: true

# A coarse "Chrome on macOS" from a user-agent string, to help someone recognise
# one of their own devices in a list. Never a fingerprint, and never trusted:
# the string is sent by the client and is free to lie.
#
# Derived at display time rather than stored, so sharpening the rules here also
# improves rows written long ago.
class DeviceLabel
  # Order matters: Edge and Chrome both claim to be Safari, Edge also claims to
  # be Chrome. Most specific first.
  #
  # On iOS every browser is Safari underneath and says so; the only thing that
  # tells them apart is a CriOS/FxiOS/EdgiOS token. Without them Chrome on an
  # iPhone reads as "Safari sur iOS" -- in a list whose whole point is telling
  # your own device from the one you mean to sign out.
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
