# frozen_string_literal: true

# Sentry hook cutting the referrer of a request down to its address. The SDK
# sends the address of a request without its parameters but the Referer header
# whole: after a prefill link, that header names the applicant (identite_nom…).
module SentryReferer
  REFERER = 'Referer'

  def self.scrub(event)
    headers = event.request&.headers
    headers[REFERER] = headers[REFERER][/\A[^?]*/] if headers&.key?(REFERER)

    event
  end
end
