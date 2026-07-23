# frozen_string_literal: true

require 'resolv'

# URLValidator does not resolve domain names: requests to a user-supplied url
# resolve it here and pin the vetted addresses on the connection.
class PublicAddressResolver
  # Refused at request time only: added to URLValidator, they would make
  # saved urls invalid.
  RESERVED_RANGES = [
    IPAddr.new('240.0.0.0/4'),    # reserved, and broadcast
    IPAddr.new('64:ff9b::/96'),   # NAT64
    IPAddr.new('64:ff9b:1::/48'), # local-use NAT64
    IPAddr.new('2002::/16'),      # 6to4
    IPAddr.new('fec0::/10'),      # site-local
  ].freeze

  # per query, A then AAAA: the default (5 s, then retries up to 40 s) would
  # let a slow name server hold a delivery run past its claim
  DNS_TIMEOUT = 2
  RESOLVER = Resolv.new([Resolv::Hosts.new, Resolv::DNS.new.tap { it.timeouts = DNS_TIMEOUT }])

  # Empty when the host is missing or unresolvable. Refuse them if any is
  # .private_address?, and pin them with .resolve_pin, or DNS rebinding
  # bypasses the check.
  def self.addresses(url)
    host = host_of(url)
    return [] if host.blank?

    ip = URLValidator.ip_literal(host)
    ip ? [ip.to_s] : RESOLVER.getaddresses(host)
  end

  def self.private_address?(address)
    ip = IPAddr.new(address).native
    URLValidator.private_ip?(ip) || RESERVED_RANGES.any? { it.include?(ip) }
  end

  # The url to request: libcurl must see the host and port the pin is for
  # (lowercase scheme, ASCII host, an IP literal in its usual form).
  def self.request_url(url)
    uri = Addressable::URI.parse(url)
    uri.scheme = uri.normalized_scheme
    uri.host = uri.normalized_host
    ip = URLValidator.ip_literal(uri.host) if uri.host.present?
    uri.host = (ip.ipv6? ? "[#{ip}]" : ip.to_s) if ip
    uri.to_s
  end

  # CURLOPT_RESOLVE entry, nil for an IP literal
  def self.resolve_pin(url, addresses)
    uri = Addressable::URI.parse(url)
    host = uri.normalized_host.delete('[]')
    return nil if URLValidator.ip_literal(host)

    FFI::AutoPointer.new(
      Ethon::Curl.slist_append(nil, "#{host}:#{uri.inferred_port}:#{addresses.join(',')}"),
      Ethon::Curl.method(:slist_free_all)
    )
  end

  def self.host_of(url)
    Addressable::URI.parse(url)&.normalized_host&.delete('[]')
  rescue Addressable::URI::InvalidURIError
    nil
  end
end
