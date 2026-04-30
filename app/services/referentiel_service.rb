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

  def call(query_params, dossier: nil)
    resolved_url = url(query_params, dossier:)
    return Failure(retryable: false, error: StandardError.new("URL could not be resolved"), code: nil) if resolved_url.nil?

    result = API::Client.new.call(
      url: resolved_url,
      timeout: @timeout,
      headers:,
      maxfilesize: MAX_FILE_SIZE
    )
    handle_api_result(result)
  end

  def url(query_params, dossier: nil)
    resolve_tiptap_url(query_params, dossier || referentiel.test_data_tiptap)
  end

  def test_url
    url(referentiel.effective_test_data)
  end

  def test_headers
    headers.transform_values { "[FILTERED]" }.map { |h, v| "#{h}: #{v}" }.join("\n")
  end

  def validate_referentiel
    case referentiel
    when Referentiels::APIReferentiel
      result = call(referentiel.effective_test_data)

      case result
      in Success
        referentiel.update_column(:last_response, { status: 200, body: result.value! })
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

  def resolve_tiptap_url(query_params, values_source)
    substitutions = build_substitutions(query_params, values_source)
    return nil if substitutions.nil?

    return nil if referentiel.url_tiptap.blank?

    TiptapService.new.to_texts_and_tags(
      referentiel.url_tiptap.deep_symbolize_keys,
      substitutions
    )
  end

  def build_substitutions(query_params, values_source)
    referentiel.tiptap_mention_ids.each_with_object({}) do |id, hash|
      value = if id == "{query}"
        query_params.presence&.to_s
      else
        extract_value(values_source, id)
      end
      return nil if value.blank?
      hash[id] = URI.encode_www_form_component(value)
    end
  end

  def extract_value(values_source, tag_id)
    case values_source
    when NilClass
      nil
    when Hash
      values_source[tag_id]
    else
      stable_id = tag_id.delete_prefix("tdc").to_i
      champ = values_source.champs.find { _1.stable_id == stable_id }
      champ&.value
    end
  end
end
