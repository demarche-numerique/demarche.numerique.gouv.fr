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
    objects.take(MAX_RENDERED_OBJECTS).map.with_index do |data, index|
      label = render_template(json_template, data.with_indifferent_access).join("")
      # Use index as unique value prefix to prevent duplicate keys when multiple items have the same label
      # This prevents infinite loops in react-stately's internal linked list structure
      # The value is only used as a React key - the actual data sent to server is the encrypted 'data' field
      {
        label:,
        value: "#{index}:#{label}",
        data: message_encryptor_service.encrypt_and_sign(data, purpose: :storage, expires_in: 1.hour),
      }
    end
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
