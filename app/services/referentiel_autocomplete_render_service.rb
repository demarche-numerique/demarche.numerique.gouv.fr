# frozen_string_literal: true

class ReferentielAutocompleteRenderService
  attr_reader :api_response, :referentiel, :json_template
  MAX_RENDERED_OBJECTS = 1000

  def initialize(api_response, referentiel)
    @api_response = api_response.is_a?(Hash) ? api_response.with_indifferent_access : api_response
    @referentiel = referentiel
    @json_template = referentiel.json_template
  end

  def format_response
    objects = JsonPath.on(api_response, referentiel.datasource).first
    objects.take(MAX_RENDERED_OBJECTS).map do |data|
      label = render_template(json_template, data.with_indifferent_access).join("")
      {
        id: Digest::MD5.hexdigest(data.to_json), # stable unique key for react-stately (not security-related)
        label:,
        value: label,
        data: message_encryptor_service.encrypt_and_sign(data, purpose: :storage, expires_in: 1.hour),
      }
    end.uniq { it[:id] }
  end

  private

  def message_encryptor_service
    @message_encryptor_service ||= MessageEncryptorService.new
  end

  def render_template(template, obj, interpolations = [])
    case template["type"]
    when "mention"
      interpolations << JSONPathUtil.on_safe(obj, template["attrs"]["id"]).first
    when "text"
      interpolations << template["text"]
    when "doc", 'paragraph'
      template['content'].each { |t| interpolations.concat(render_template(t, obj)) }
    else
      raise "Unknown template type: #{template['type']}. Expected one of: mention, text, doc, paragraph."
    end
    interpolations
  end
end
