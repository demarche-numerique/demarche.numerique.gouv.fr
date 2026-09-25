# frozen_string_literal: true

# A URL the browser handed us -- a referer, a redirect target -- is worth
# something only once it is proven to point back at us. Scheme, host and port,
# because any of the three is enough to send someone somewhere else.
module SameOriginUri
  def self.parse(url, request)
    return if url.blank?

    uri = URI.parse(url)

    return unless uri.scheme == request.scheme
    return unless uri.host == request.host
    return unless uri.port == request.port

    uri
  rescue URI::InvalidURIError
    nil
  end
end
