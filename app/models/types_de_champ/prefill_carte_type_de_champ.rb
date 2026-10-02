# frozen_string_literal: true

class TypesDeChamp::PrefillCarteTypeDeChamp < TypesDeChamp::PrefillTypeDeChamp
  def example_value
    { type: 'Point', coordinates: [2.3086, 48.8495] }.to_json
  end

  # Accepts a single GeoJSON geometry, as a JSON string (prefill link) or an
  # object (POST body), and turns it into the champ's only geo area.
  def to_assignable_attributes(champ, value)
    geometry = parse_geometry(value)
    return nil if geometry.nil?

    geo_area = GeoArea.new(source: GeoArea.sources.fetch(:selection_utilisateur), geometry:, properties: {})
    return nil if !geo_area.drawable? || geo_area.tap(&:validate).errors.include?(:geometry)

    { geo_areas: [geo_area] }
  end

  private

  def parse_geometry(value)
    geometry = value.is_a?(String) ? JSON.parse(value) : value
    geometry.deep_stringify_keys.slice('type', 'coordinates') if geometry.is_a?(Hash)
  rescue JSON::ParserError
    nil
  end
end
