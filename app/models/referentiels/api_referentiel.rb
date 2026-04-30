# frozen_string_literal: true

class Referentiels::APIReferentiel < Referentiel
  # An encrypted JSON object is used to store authentication data securely and flexibly.
  # This allows us to store various authentication methods in a single field.
  # Examples of authentication_data structure:
  #
  #   Basic Auth : { "username": "...", "password": "..." }
  #   OAuth2 : { "client_id": "...", "client_secret": "...", "token_url": "..." }
  #   Custom header : { "header": "X-API-Key", "value": "..." }
  #   JWT : { "header": "Authorization", "value": "Bearer ...", "jwt_options": {...} }
  encrypts :authentication_data

  enum :mode, {
    exact_match: 'exact_match',
    autocomplete: 'autocomplete',
  }

  validates :mode, inclusion: { in: modes.values }
  validate :url_allowed?
  validates :url_tiptap, presence: true
  validate :validate_tiptap_test_data

  store_accessor :autocomplete_configuration, :datasource, :json_template
  before_save :name_as_uuid
  before_save :resets_tiptap_template

  def self.stub_url
    ENV.fetch('ALLOWED_API_DOMAINS_FROM_FRONTEND')
      .split(',')
      .last
  end

  def self.csv_available?
    false
  end

  def resets_tiptap_template
    if datasource_changed? && !datasource_was.nil?
      self.json_template = {}
    end
  end

  def tiptap_template=(value)
    self.json_template = JSON.parse(value)
  end

  def tiptap_template
    json_template&.to_json
  end

  def url_tiptap=(value)
    super(value.is_a?(String) ? JSON.parse(value) : value)
  rescue JSON::ParserError
    super(value)
  end

  def tiptap_paragraph_nodes
    return [] if url_tiptap.blank?
    url_tiptap.dig("content", 0, "content") || []
  end

  def tiptap_mention_ids
    tiptap_paragraph_nodes
      .filter { _1["type"] == "mention" }
      .filter_map { _1.dig("attrs", "id") }
  end

  def tiptap_mention_stable_ids
    tiptap_mention_ids
      .filter { _1.start_with?("tdc") }
      .map { _1.delete_prefix("tdc").to_i }
  end

  def url_has_query_tag?
    tiptap_paragraph_nodes.any? { _1["type"] == "mention" && _1.dig("attrs", "id") == "{query}" }
  end

  def test_data_tags
    return [] if url_tiptap.blank?
    TiptapService.used_tags_and_libelle_for(url_tiptap.deep_symbolize_keys)
      .map { |id, label| { id:, label: } }
  end

  def effective_test_data
    test_data_tiptap&.dig("{query}")
  end

  def last_response_body
    (last_response || {}).fetch("body") { {} }
  end

  def last_response_status
    (last_response || {}).fetch("status") { 500 }
  end

  def ready?
    configured? && last_response_status == 200
  end

  def configured?
    case type
    when "Referentiels::APIReferentiel"
      [mode.present?, url_tiptap.present?, tiptap_test_data_complete?].all?
    when "Referentiels::CsvReferentiel"
      false
    else
      false
    end
  end

  def authentication_data_header
    authentication_data&.fetch('header', '')
  end

  def authentication_header_token
    authentication_data&.fetch('value', '')
  end

  def authentication_by_header_token?
    [
      authentication_method == 'header_token',
      authentication_data_header.present?,
      authentication_header_token.present?,
    ].all?
  end

  def url_from_tiptap_for_validation
    nodes = tiptap_paragraph_nodes
    return nil if nodes.empty?

    nodes
      .filter { _1["type"] == "text" }
      .map { _1["text"] }
      .join
  end

  def url_allowed?
    raw_url = url_from_tiptap_for_validation

    if raw_url.blank?
      errors.add(:url_tiptap, :invalid_format) if url_tiptap.present?
      return
    end

    uri = Addressable::URI.parse(raw_url)

    if uri.scheme.blank? || uri.scheme != 'https'
      errors.add(:url_tiptap, :https_required)
    end

    if tiptap_mention_ids.empty?
      errors.add(:url_tiptap, :missing_query_params)
    end

    unless uri.tld == "gouv.fr" && uri.domain != "beta.gouv.fr"
      allowed_hosts = ENV.fetch('ALLOWED_API_DOMAINS_FROM_FRONTEND', '').split(',').filter_map { Addressable::URI.parse(_1).host rescue nil }
      if uri.host.blank? || allowed_hosts.none? { uri.host == _1 || uri.host.end_with?(".#{_1}") }
        errors.add(:url_tiptap, :not_allowed, contact_email: CONTACT_EMAIL)
      end
    end
  rescue Addressable::URI::InvalidURIError, URI::InvalidURIError, PublicSuffix::DomainInvalid
    errors.add(:url_tiptap, :invalid_format)
  end

  private

  def tiptap_test_data_complete?
    ids = tiptap_mention_ids
    return true if ids.empty?

    ids.all? { test_data_tiptap&.dig(_1).present? }
  end

  def validate_tiptap_test_data
    tiptap_mention_ids.each do |id|
      next if test_data_tiptap&.dig(id).present?

      errors.add(:"test_data_tiptap_#{id}", "doit être renseigné")
    end
  end

  def name_as_uuid # should be uniq, using the url was an idea but not unique
    self.name = SecureRandom.uuid
  end
end
