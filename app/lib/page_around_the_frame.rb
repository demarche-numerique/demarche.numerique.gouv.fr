# frozen_string_literal: true

# A Turbo frame asks for a fragment of a page. Coming back to it after signing
# in would show the fragment alone: where the person was is the page around it,
# which the browser sends as the referer.
module PageAroundTheFrame
  def self.location(request)
    return if request.headers['Turbo-Frame'].blank?

    uri = SameOriginUri.parse(request.referer, request)

    return if uri.nil? || uri.path.blank?

    [uri.path, uri.query].compact.join('?')
  end
end
