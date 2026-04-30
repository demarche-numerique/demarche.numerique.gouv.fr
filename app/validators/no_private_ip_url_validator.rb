# frozen_string_literal: true

require 'resolv'
require 'addressable/uri'
require 'ipaddr'

class NoPrivateIPURLValidator < ActiveModel::EachValidator
  PRIVATE_RANGES = [
    IPAddr.new('127.0.0.0/8'),       # loopback
    IPAddr.new('10.0.0.0/8'),        # RFC 1918
    IPAddr.new('172.16.0.0/12'),     # RFC 1918
    IPAddr.new('192.168.0.0/16'),    # RFC 1918
    IPAddr.new('169.254.0.0/16'),    # link-local
    IPAddr.new('0.0.0.0/8'),         # unspecified
    IPAddr.new('::1/128'),           # IPv6 loopback
    IPAddr.new('fc00::/7'),          # IPv6 unique local
    IPAddr.new('fe80::/10'),         # IPv6 link-local
  ].freeze

  def self.private_ip?(ip_string)
    ip = IPAddr.new(ip_string)
    PRIVATE_RANGES.any? { _1.include?(ip) }
  rescue IPAddr::InvalidAddressError
    false
  end

  def validate_each(record, attribute, value)
    return if value.blank?

    uri = Addressable::URI.parse(value)
    host = uri&.host
    return if host.blank?

    if private_ip_host?(host)
      record.errors.add(attribute, options[:message] || :private_ip_url)
    end
  rescue Addressable::URI::InvalidURIError
    # URL format validation is handled by URLValidator
  end

  private

  def private_ip_host?(host)
    # Strip IPv6 brackets if present
    clean_host = host.gsub(/\[|\]/, '')

    # Direct IP address check
    ip = IPAddr.new(clean_host)
    self.class.private_ip?(ip.to_s)
  rescue IPAddr::InvalidAddressError
    # Not an IP literal — it's a hostname, skip DNS resolution at validation time
    # DNS resolution check happens at request time in WebHookJob
    false
  end
end
