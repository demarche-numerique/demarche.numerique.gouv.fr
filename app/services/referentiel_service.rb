# frozen_string_literal: true

class ReferentielService
  include Dry::Monads[:result]

  RETRYABLE_STATUS_CODES = [429, 500, 503, 504, 408, 502].freeze
  NON_RETRYABLE_STATUS_CODES = [404, 400, 403, 401].freeze
  # types returned by API::Client when no HTTP response was received: transient, worth retrying
  RETRYABLE_ERROR_TYPES = [:timeout, :network].freeze

  API_TIMEOUT = 4 # in seconds
  MAX_FILE_SIZE = 1.megabyte

  USAGER_INPUT_TAG = "{query}"
  DOSSIER_NUMBER_TAG = "{dossier_number}"

  attr_reader :referentiel, :service

  def initialize(referentiel:, timeout: API_TIMEOUT)
    @referentiel = referentiel
    @timeout = timeout
  end

  def call(query_params, dossier: nil, row_id: nil)
    resolved_url = url(query_params, dossier:, row_id:)
    return Failure(retryable: false, error: StandardError.new("URL could not be resolved"), code: nil) if resolved_url.nil?

    result = API::Client.new.call(
      url: resolved_url,
      timeout: @timeout,
      headers:,
      maxfilesize: MAX_FILE_SIZE
    )
    handle_api_result(result)
  end

  def url(query_params, dossier: nil, row_id: nil)
    resolve_tiptap_url(query_params, dossier || referentiel.test_data_tiptap, row_id)
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
    in Failure(type:, code:) if type.in?(RETRYABLE_ERROR_TYPES) # network issue or timeout, api may recover
      Failure(retryable: true, error: StandardError.new("Retryable: #{type}"), code:)
    in Failure(code:) if code.in?(RETRYABLE_STATUS_CODES) # api may be rate limited, or down etc..
      Failure(retryable: true, error: StandardError.new("Retryable: #{code}"), code:)
    in Failure(code:) if code.in?(NON_RETRYABLE_STATUS_CODES) # search may not have been found
      Failure(retryable: false, error: StandardError.new("Not retryable: #{code}"), code:)
    in Failure(type:, code:)
      Failure(retryable: false, error: StandardError.new("Unknown error: #{type} (code: #{code})"), code:)
    end
  end

  def headers
    if referentiel.authentication_by_header_token?
      { referentiel.authentication_data_header => referentiel.authentication_header_token }
    else
      {}
    end
  end

  def resolve_tiptap_url(query_params, values_source, row_id = nil)
    substitutions = build_substitutions(query_params, values_source, row_id)
    return nil if substitutions.nil?

    # Pas referentiel.url_tiptap entier : seulement les nœuds que valide url_allowed?.
    url_nodes = referentiel.tiptap_paragraph_nodes
    return nil if url_nodes.empty?

    TiptapService.new.to_texts_and_tags({ content: url_nodes }.deep_symbolize_keys, substitutions)
  end

  def build_substitutions(query_params, values_source, row_id = nil)
    referentiel.tiptap_mention_ids.each_with_object({}) do |id, hash|
      value = if id == USAGER_INPUT_TAG
        query_params.presence&.to_s
      else
        extract_value(values_source, id, row_id)
      end
      return nil if value.blank?
      hash[id] = URI.encode_www_form_component(value)
    end
  end

  def extract_value(values_source, tag_id, row_id = nil)
    case values_source
    when NilClass
      nil
    when Hash
      values_source[tag_id]
    else
      # Le numéro de dossier ne vient pas d'un champ : il se lit sur le dossier lui-même.
      return values_source.id&.to_s if tag_id == DOSSIER_NUMBER_TAG

      stable_id = tag_id.delete_prefix("tdc").to_i
      champ_for_tag(values_source, stable_id, row_id)&.value
    end
  end

  # Le tag est résolu sur les champs que le champ référentiel appelant peut référencer :
  # ceux de sa propre ligne de répétition, et ceux hors répétition. Jamais ceux d'une
  # autre ligne : mieux vaut ne pas résoudre l'URL que d'appeler l'API avec la donnée
  # d'une ligne voisine.
  # Sans contexte de ligne (référentiel hors répétition), un tag visant une répétition
  # n'a pas de ligne de référence : on garde alors le premier champ rempli.
  def champ_for_tag(dossier, stable_id, row_id)
    champ = dossier.champs_for_row(row_id).find { it.stable_id == stable_id }
    return champ if champ.present? || row_id.present?

    dossier.champs.filter { it.stable_id == stable_id }.compact_blank.first
  end
end
