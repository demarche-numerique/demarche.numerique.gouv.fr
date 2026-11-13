# frozen_string_literal: true

require 'resolv'

# URLValidator does not resolve domain names: requests to a user-supplied url
# resolve it here and pin the vetted addresses on the connection.
class PublicAddressResolver
  # Empty when the host is missing or unresolvable. Refuse them if any is
  # .private_address?, and pin them with .resolve_pin, or DNS rebinding
  # bypasses the check.
  def self.addresses(url)
    host = host_of(url)
    return [] if host.blank?

    ip_literal?(host) ? [host] : Resolv.getaddresses(host)
  end

  def self.private_address?(address)
    URLValidator.private_ip?(IPAddr.new(address).native)
  end

  # The url to request: libcurl must see the host and port the pin is for
  # (lowercase scheme, ASCII host).
  def self.request_url(url)
    uri = Addressable::URI.parse(url)
    uri.scheme = uri.normalized_scheme
    uri.host = uri.normalized_host
    uri.to_s
  end

  # CURLOPT_RESOLVE entry, nil for an IP literal
  def self.resolve_pin(url, addresses)
    uri = Addressable::URI.parse(url)
    host = uri.normalized_host.delete('[]')
    return nil if ip_literal?(host)

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

  def self.ip_literal?(host)
    IPAddr.new(host)
    true
  rescue IPAddr::InvalidAddressError
    false
  end
end
