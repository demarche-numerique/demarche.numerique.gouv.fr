# frozen_string_literal: true

class ReferentielService
  include Dry::Monads[:result]

  RETRYABLE_STATUS_CODES = [429, 500, 503, 408, 502].freeze
  NON_RETRYABLE_STATUS_CODES = [404, 400, 403, 401].freeze

  API_TIMEOUT = 4 # in seconds
  MAX_FILE_SIZE = 1.megabyte

  attr_reader :referentiel, :service

  def initialize(referentiel:, timeout: API_TIMEOUT)
    @referentiel = referentiel
    @timeout = timeout
  end

  def call(query_params)
    result = API::Client.new.call(
      url: url(query_params),
      timeout: @timeout,
      headers:,
      maxfilesize: MAX_FILE_SIZE
    )
    handle_api_result(result)
  end

  def url(query_params)
    referentiel.url.gsub('{id}', URI.encode_www_form_component(query_params.to_s))
  end

  def test_url
    url(@referentiel.test_data)
  end

  def test_headers
    headers.transform_values { "[FILTERED]" }.map { |h, v| "#{h}: #{v}" }.join("\n")
  end

  def validate_referentiel
    case referentiel
    when Referentiels::APIReferentiel
      result = call(referentiel.test_data)
      case result
      in Success
        body = result.value!
        referentiel.update_column(:last_response, { status: 200, body: })
        true
      in Failure(data)
        referentiel.update_column(:last_response, { status: data[:code], body: data[:body] })
        false
      end
    end
  end

  private

  def handle_api_result(result)
    case result
    in Success(body:)
      Success(body)
    in Failure(code:) if code.in?(RETRYABLE_STATUS_CODES) # api may be rate limited, or down etc..
      Failure(retryable: true, error: StandardError.new("Retryable: #{code}"), code:)
    in Failure(code:) if code.in?(NON_RETRYABLE_STATUS_CODES) # search may not have been found
      Failure(retryable: false, error: StandardError.new("Not retryable: #{code}"), code:)
    in Failure
      Failure(retryable: false, error: StandardError.new('Unknown error'), code:)
    end
  end

  def headers
    if referentiel.authentication_by_header_token?
      { referentiel.authentication_data_header => referentiel.authentication_header_token }
    else
      {}
    end
  end
end
