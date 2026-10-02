# frozen_string_literal: true

# An http(s) url whose host is a dotted name or an ip literal, or with
# `accept_email: true`, an email.
# A host that is local or on a private network is rejected: an ip literal of
# such a network, localhost, or a single label like "intranet". Domain names
# are not resolved.
class URLValidator < ActiveModel::EachValidator
  # what IPAddr#private?, #loopback? and #link_local? leave out
  RESERVED_RANGES = [
    IPAddr.new('0.0.0.0/8'),     # "this network": 0.0.0.0 reaches the host itself
    IPAddr.new('100.64.0.0/10'), # carrier-grade NAT
    IPAddr.new('::/128'),        # unspecified
  ].freeze

  # a scheme, not a host followed by its port (www.mairie.fr:8080)
  SCHEME = /\A[a-z][a-z0-9+.\-]*:(?!\d)/i

  # What an admin types or pastes, made into what the validator expects:
  # " www.mairie.fr/dpo " is https://www.mairie.fr/dpo, "mailto:DPO@mairie.fr"
  # is dpo@mairie.fr. Anything else with a scheme is left for the validation.
  def self.normalize(value)
    link = value.gsub(/\A[[:space:]]+|[[:space:]]+\z/, '').sub(/\Amailto:/i, '')

    if link.blank?
      nil
    elsif link.include?('@') && !link.match?(SCHEME)
      EmailSanitizableConcern::EmailSanitizer.sanitize(link)
    elsif !link.match?(SCHEME)
      "https://#{link.delete_prefix('//')}"
    else
      link
    end
  end

  def self.private_ip?(ip)
    ip.private? || ip.loopback? || ip.link_local? || RESERVED_RANGES.any? { it.include?(ip) }
  end

  def validate_each(record, attribute, value)
    return if options[:accept_email] && email?(value)

    uri = Addressable::URI.parse(value)
    if uri.host.present? && local_host?(uri.host)
      record.errors.add(attribute, :private_ip_url)
    elsif !url?(uri)
      record.errors.add(attribute, :url)
    end
  rescue Addressable::URI::InvalidURIError
    record.errors.add(attribute, :url)
  end

  private

  # a name needs a dot, an ip literal does not ([2606:4700::1111]): local ones are rejected before
  def url?(uri)
    uri.normalized_scheme.in?(['http', 'https']) && uri.host.present? && (uri.host.include?('.') || ip_literal(uri.host).present?)
  end

  # the regexp alone: StrictEmailValidator falls back to a laxer one for older records
  def email?(value) = StrictEmailValidator::REGEXP.match?(value)

  def local_host?(host)
    ip = ip_literal(host)
    ip ? self.class.private_ip?(ip) : internal_name?(host)
  end

  def internal_name?(host)
    name = host.downcase.delete_suffix('.')
    !name.include?('.') || name.end_with?('.localhost')
  end

  # The host read as the system reads a numeric one, without any DNS query:
  # 2130706433, 0x7f.0.0.1, 0177.0.0.1 and 127.1 are 127.0.0.1,
  # ::ffff:127.0.0.1 is 127.0.0.1 too.
  def ip_literal(host)
    address = Addrinfo.getaddrinfo(host.delete('[]'), nil, nil, :STREAM, nil, Socket::AI_NUMERICHOST).first.ip_address
    IPAddr.new(address).native
  rescue SocketError
    nil # a domain name
  end
end
