# frozen_string_literal: true

class GeojsonService
  def self.valid_schema?(json)
    schemer = JSONSchemer.schema(Rails.root.join('app/schemas/geojson.json'))
    if schemer.valid?(json)
      if ActiveRecord::Base.connection.execute("SELECT 1 as one FROM pg_extension WHERE extname = 'postgis';").count.zero?
        true
      else
        ActiveRecord::Base.connection.exec_query('select ST_IsValid(ST_GeomFromGeoJSON($1)) as valid;', 'ValidateGeoJSON', [json.to_json]).first['valid']
      end
    end
  end

  def self.valid_wgs84_coordinates?(geometry)
    coordinates = []
    yield_each_coordinate_in_geojson(geometry.with_indifferent_access) { |coord| coordinates.push(coord) }
    coordinates.all? { |coord| valid_wgs84_coord?(coord) }
  rescue => e
    Sentry.capture_exception(e, extra: { geometry: geometry })
    false
  end

  # Check if the coordinates are valid WGS84 coordinates
  # valid WGS84 coordinates are in the range of:
  # longitude: -180 to 180
  # latitude: -90 to 90
  def self.valid_wgs84_coord?(coord)
    return false unless coord.is_a?(Array) && coord.size >= 2
    lng, lat = coord[0], coord[1]
    lng >= -180 && lng <= 180 && lat >= -90 && lat <= 90
  end

  # The following code is ported from turfjs
  # https://github.com/Turfjs/turf/blob/master/packages/turf-area/index.ts

  EQUATORIAL_RADIUS = 6378137

  def self.area(geojson)
    calculate_area(geojson)
  end

  def self.length(geojson)
    segment_reduce(geojson, 0) do |previous_value, segment|
      coordinates = segment[:geometry][:coordinates]
      previous_value + distance(coordinates[0], coordinates[1])
    end
  end

  def self.distance(from, to)
    coordinates1 = from
    coordinates2 = to
    d_lat = degrees_to_radians(coordinates2[1] - coordinates1[1])
    d_lon = degrees_to_radians(coordinates2[0] - coordinates1[0])
    lat1 = degrees_to_radians(coordinates1[1])
    lat2 = degrees_to_radians(coordinates2[1])

    a = (Math.sin(d_lat / 2)**2) + (Math.sin(d_lon / 2)**2) * Math.cos(lat1) * Math.cos(lat2)

    radians = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    radians * EQUATORIAL_RADIUS
  end

  def self.bbox(geojson)
    result = [-Float::INFINITY, -Float::INFINITY, Float::INFINITY, Float::INFINITY]

    self.yield_each_coordinate_in_geojson(geojson) do |coord|
      if result[3] > coord[1]
        result[3] = coord[1]
      end
      if result[2] > coord[0]
        result[2] = coord[0]
      end
      if result[1] < coord[1]
        result[1] = coord[1]
      end
      if result[0] < coord[0]
        result[0] = coord[0]
      end
    end

    result
  end

  # Extrait la liste des géométries d’un GeoJSON (FeatureCollection, Feature, Geometry, etc.)
  def self.geometries_from_geojson(geojson)
    case geojson[:type]
    when "FeatureCollection"
      geojson[:features].map { |f| f[:geometry] }
    when "Feature"
      [geojson[:geometry]]
    else
      [geojson]
    end.compact
  end

  # Itère sur toutes les coordonnées de toutes les géométries d’un GeoJSON
  def self.yield_each_coordinate_in_geojson(geojson)
    geometries = geometries_from_geojson(geojson)
    geometries.each do |geometry|
      next unless geometry && geometry[:type]

      case geometry[:type]
      when "GeometryCollection"
        geometry[:geometries].each { |g| yield_each_coordinate_in_geometry(g) { |c| yield c } }
      when "Point"
        yield geometry[:coordinates].map(&:to_f)
      when "LineString", "MultiPoint"
        geometry[:coordinates].each { |c| yield c.map(&:to_f) }
      when "Polygon", "MultiLineString"
        geometry[:coordinates].each { |shapes| shapes.each { |c| yield c.map(&:to_f) } }
      when "MultiPolygon"
        geometry[:coordinates].each { |polygons| polygons.each { |shapes| shapes.each { |c| yield c.map(&:to_f) } } }
      end
    end
  end

  def self.calculate_area(geom)
    total = 0
    case geom[:type]
    when 'Polygon'
      polygon_area(geom[:coordinates]);
    when 'MultiPolygon'
      geom[:coordinates].each do |coordinates|
        total += polygon_area(coordinates)
      end
      total
    else
      total
    end
  end

  def self.polygon_area(coordinates)
    total = 0
    if coordinates.present?
      coordinates = coordinates.dup
      total += ring_area(coordinates.shift).abs
      coordinates.each do |coordinates|
        total -= ring_area(coordinates).abs
      end
    end
    total
  end

  def self.ring_area(coordinates)
    total = 0
    coords_length = coordinates.size

    if coords_length > 2
      coords_length.times do |i|
        if i == coords_length - 2 # i = N-2
          lower_index = coords_length - 2
          middle_index = coords_length - 1
          upper_index = 0
        elsif i == coords_length - 1 # i = N-1
          lower_index = coords_length - 1
          middle_index = 0
          upper_index = 1
        else # i = 0 to N-3
          lower_index = i
          middle_index = i + 1
          upper_index = i + 2
        end
        p1 = coordinates[lower_index]
        p2 = coordinates[middle_index]
        p3 = coordinates[upper_index]
        total += (rad(p3[0]) - rad(p1[0])) * Math.sin(rad(p2[1]))
      end
      total = total * EQUATORIAL_RADIUS * EQUATORIAL_RADIUS / 2
    end

    total
  end

  def self.segment_reduce(geojson, initial_value)
    previous_value = initial_value
    started = false
    coordinates = geojson[:coordinates].dup
    from = coordinates.shift
    coordinates.each do |to|
      current_segment = { type: 'Feature', geometry: { type: 'LineString', coordinates: [from, to] } }
      from = to
      if started == false && initial_value.blank?
        previous_value = current_segment
      else
        previous_value = yield previous_value, current_segment
      end
      started = true
    end
    previous_value
  end

  def self.rad(num)
    num * Math::PI / 180
  end

  def self.degrees_to_radians(degrees)
    rad(degrees % 360)
  end
end
