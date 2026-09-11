# frozen_string_literal: true

class JSONPathUtil
  def self.on_safe(json, jsonpath)
    normalized_json = normalize_keys(json.is_a?(Hash) ? json.with_indifferent_access : json)
    sanitized_jsonpath = jsonpath.split('.').map { sanitize_segment(it) }.join('.')

    JsonPath.on(normalized_json, sanitized_jsonpath)
  end

  def self.normalize_keys(obj)
    case obj
    when Hash
      obj.transform_keys { sanitize_segment(it) }
        .transform_values { normalize_keys(it) }
    when Array
      obj.map { normalize_keys(it) }
    else
      obj
    end
  end

  # Sanitiser un segment du JSONPath : appliquer parameterize seulement à la clé, pas à l'indice
  def self.sanitize_segment(segment)
    if segment.include?('[')
      key = segment.split('[').first
      index = segment[/\[.*\]/]
      "#{key.parameterize}#{index}"
    else
      segment.parameterize
    end
  end

  def self.filter_selectable_datasources(json, parent_path = '$')
    if json.is_a?(Hash)
      json.each_with_object({}) do |(key, value), result|
        json_path = "#{parent_path}.#{key}"

        case value
        in [Hash => first, *] => suggestions
          result.merge!(json_path => suggestions)
        in Hash
          nested = filter_selectable_datasources(value, json_path)
          result.merge!(nested)
        else
          result
        end
      end
    elsif json.is_a?(Array)
      { "#{parent_path}." => json }
    else
      {}
    end
  end

  def self.hash_to_jsonpath(json, parent_path = '$')
    if json.is_a?(Hash)
      json.each_with_object({}) do |(key, value), result|
        current_path = "#{parent_path}.#{key}"

        case value
        in Hash
          result.merge!(hash_to_jsonpath(value, current_path))
        in [Hash => first, *]
          result.merge!(hash_to_jsonpath(first, "#{current_path}[0]"))
        else
          result[current_path] = value
        end
      end
    elsif json.is_a?(Array)
      hash_to_jsonpath(json.first, "#{parent_path}.[0]")
    else
      {}
    end
  end

  # Plus long préfixe commun de plusieurs chemins, segment par segment :
  # "$.records[0].id" et "$.records[0].fields.Nom" donnent "$.records[0]".
  def self.common_prefix(jsonpaths)
    return nil if jsonpaths.blank?

    segments = jsonpaths.map { it.split('.') }
    segments.first
      .take_while.with_index { |segment, index| segments.all? { it[index] == segment } }
      .join('.')
  end

  # navigation
  def self.extract_array_name(str)
    str[/^[^\[]+/]
  end

  def self.json_path_contains_array?(str)
    str.include?('[') && str.include?(']')
  end

  def self.extract_key_after_array(str)
    str[/\[(.*?)\](.*)/, 2]
  end
end
