# frozen_string_literal: true

module Typhoeus
  # Exchanges with our external providers are invisible from the application. In
  # development, trace one greppable line per outgoing call, whatever the call
  # site — direct Typhoeus.get/post, API::Client, or a Hydra:
  #
  #   tail -f log/development.log | grep '\[HTTP\]'
  #
  # Deliberately limited to verb, host, path and status: no query string, no
  # headers, no body. The query string alone carries pre-signed storage
  # signatures (DownloadManager::ParallelDownloadQueue), API Particulier's civil
  # status params, and administrator webhook tokens (WebHookJob); headers and
  # userpwd carry every bearer token we hold.
  #
  # Development only, on purpose: Sentry turns every Rails.logger write into a
  # breadcrumb (breadcrumbs_logger = [:active_support_logger]) while
  # send_default_pii is false.
  module Trace
    TAG = "[HTTP]"

    class << self
      # Returns the response: registered as a Typhoeus.on_complete callback, the
      # return value becomes response.handled_response, and the response is what
      # it already defaults to.
      def log(response)
        request = response.request

        Rails.logger.info("#{TAG} #{verb(request)} #{endpoint(request)} → #{response.code} (#{detail(response)})")

        response
      rescue => e
        # A comfort trace must never break the call it observes.
        Rails.logger.debug { "#{TAG} untraceable call (#{e.class})" }

        response
      end

      private

      def verb(request) = (request.options[:method] || :get).to_s.upcase

      def endpoint(request)
        url = request.base_url.to_s
        uri = URI.parse(url)

        "#{uri.host}#{uri.path}"
      rescue URI::InvalidURIError
        url.split("?", 2).first
      end

      def detail(response)
        if response.cached?
          "cache"
        elsif response.code.zero?
          response.return_code.presence || "no response"
        else
          "#{(response.total_time.to_f * 1000).round}ms"
        end
      end
    end
  end
end
