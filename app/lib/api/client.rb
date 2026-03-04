# frozen_string_literal: true

class API::Client
  include Dry::Monads[:result]

  TIMEOUT = 10

  def call(url:, params: nil, body: nil, json: nil, headers: nil, method: :get, authorization_token: nil, schema: nil, timeout: TIMEOUT, **typhoeus_options)
    response = case method
    when :get
      Typhoeus.get(url,
        headers: headers_with_authorization(headers, false, authorization_token:),
        params:,
        timeout:,
        **typhoeus_options)
    when :post
      Typhoeus.post(url,
        headers: headers_with_authorization(headers, json, authorization_token:),
        body: json.nil? ? body : json.to_json,
        timeout:,
        **typhoeus_options)
    when :patch
      Typhoeus.patch(url,
        headers: headers_with_authorization(headers, json, authorization_token:),
        body: json.nil? ? body : json.to_json,
        timeout:,
        **typhoeus_options)
    when :delete
      Typhoeus.delete(url,
        headers: headers_with_authorization(headers, json, authorization_token:),
        body: json.nil? ? body : json.to_json,
        timeout:,
        **typhoeus_options)
    end
    handle_response(response, schema:)
  rescue StandardError => error
    if error.is_a?(URI::InvalidURIError)
      Failure(Error[:uri, 0, false, error])
    else
      Failure(Error[:error, 0, false, error])
    end
  end

  private

  def headers_with_authorization(headers, json, authorization_token:)
    headers ||= {}

    if authorization_token.present?
      headers['authorization'] = "Bearer #{authorization_token}"
    end

    headers['content-type'] = 'application/json' if !json.nil?
    headers
  end

  OK = Data.define(:body, :response)
  Error = Data.define(:type, :code, :retryable, :error)

  def handle_response(response, schema:)
    if response.success?
      scope = Sentry.get_current_scope
      if scope.extra.key?(:external_id)
        scope.set_extras(raw_body: response.body.to_s)
      end

      # Typhoeus normalize headers key names with [] method.
      body = if response.headers && response.headers["content-type"] == "text/plain"
        Success(response.body)
      else
        parse_body(response.body)
      end

      case body
      when Success
        value = body.value!
        case value
        when Hash
          if !schema || schema.valid?(value.deep_stringify_keys)
            Success(OK[value, response])
          else
            Failure(Error[:schema, response.code, false, SchemaError.new(schema.validate(value))])
          end
        when String
          Success(OK[value, response])
        when Array
          Success(OK[value, response])
        else
          Failure(Error[:unexpected_type, response.code, false, "Unexpected body type: #{value.class}"])
        end
      when Failure
        Failure(Error[:json, response.code, false, body.failure])
      end
    elsif response.timed_out?
      Failure(Error[:timeout, response.code, true, HTTPError.new(response)])
    elsif response.code != 0
      Failure(Error[:http, response.code, true, HTTPError.new(response)])
    else
      Failure(Error[:network, response.code, true, HTTPError.new(response)])
    end
  end

  def parse_body(body)
    Success(JSON.parse(body, symbolize_names: true))
  rescue JSON::ParserError => error
    Failure(error)
  end

  class SchemaError < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors.to_a

      super(@errors.map(&:to_json).join("\n"))
    end
  end

  class HTTPError < StandardError
    attr_reader :response

    def initialize(response)
      @response = response

      uri = URI.parse(response.effective_url)

      msg = <<~TEXT
        url: #{uri.host}#{uri.path}
        HTTP error code: #{response.code}
        body: #{CGI.escape(response.body)}
        curl message: #{response.return_message}
        total time: #{response.total_time}
        connect time: #{response.connect_time}
        response headers: #{response.headers}
      TEXT

      super(msg)
    end
  end
end
