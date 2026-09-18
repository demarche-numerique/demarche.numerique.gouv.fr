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
    IPAddr.new('100.64.0.0/10'),     # CGNAT (RFC 6598)
    IPAddr.new('0.0.0.0/8'),         # unspecified
    IPAddr.new('::1/128'),           # IPv6 loopback
    IPAddr.new('fc00::/7'),          # IPv6 unique local
    IPAddr.new('fe80::/10'),         # IPv6 link-local
    IPAddr.new('64:ff9b::/96'),      # NAT64 (RFC 6052)
  ].freeze

  def self.private_ip?(ip_string)
    ip = IPAddr.new(ip_string)
    # An IPv4-mapped IPv6 address (::ffff:127.0.0.1) reaches the IPv4 host:
    # compare its native form against the IPv4 ranges.
    ip = ip.native
    PRIVATE_RANGES.any? { _1.include?(ip) }
  rescue IPAddr::InvalidAddressError
    false
  end

  # Request-time half of the guard: resolves the URL's host and returns the
  # addresses to deliver to, or nil when the host is missing, unresolvable or
  # any answer is private. Callers must pin the returned addresses on the
  # outgoing connection (see .resolve_pin) — vetting alone is bypassable by
  # DNS rebinding between this lookup and the client's own.
  def self.vetted_public_addresses(url)
    host = host_of(url)
    return nil if host.blank?

    addresses = ip_literal?(host) ? [host] : Resolv.getaddresses(host)
    return nil if addresses.empty? || addresses.any? { private_ip?(it) }

    addresses
  end

  # CURLOPT_RESOLVE entry pinning the vetted addresses, so libcurl connects to
  # them instead of running a second, rebindable DNS resolution. nil for an IP
  # literal (no resolution to pin).
  def self.resolve_pin(url, addresses)
    uri = Addressable::URI.parse(url)
    host = uri.host.delete('[]')
    return nil if ip_literal?(host)

    port = uri.port || (uri.scheme == 'https' ? 443 : 80)
    FFI::AutoPointer.new(
      Ethon::Curl.slist_append(nil, "#{host}:#{port}:#{addresses.join(',')}"),
      Ethon::Curl.method(:slist_free_all)
    )
  end

  def self.host_of(url)
    Addressable::URI.parse(url)&.host&.delete('[]')
  rescue Addressable::URI::InvalidURIError
    nil
  end

  def self.ip_literal?(host)
    IPAddr.new(host)
    true
  rescue IPAddr::InvalidAddressError
    false
  end

  def validate_each(record, attribute, value)
    return if value.blank?

    host = self.class.host_of(value)
    # A malformed URL is handled by URLValidator; a hostname is deliberately
    # not resolved here (DNS can change after validation) — server-side
    # deliveries check it at request time via .vetted_public_addresses.
    return if host.blank?

    if self.class.private_ip?(host)
      record.errors.add(attribute, options[:message] || :private_ip_url)
    end
  end
end
