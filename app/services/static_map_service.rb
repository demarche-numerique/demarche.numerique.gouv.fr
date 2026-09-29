# frozen_string_literal: true

# Renders a GeoJSON FeatureCollection as a raster image over an IGN basemap.
# Used to freeze carte champs into PDF exports, where the interactive map is
# not available.
#
# Geometries are projected to EPSG:3857 (Web Mercator) and the WMS is queried
# in the same projection. Asking the WMS for EPSG:4326 would give a plate
# carrée projection, squashed horizontally by a factor of 1/cos(latitude) —
# about 1.5 at French latitudes.
class StaticMapService
  DEFAULT_SIZE = 800

  # Radius of the extent when the geometry has no area (a lone point), in
  # metres.
  POINT_RADIUS = 50
  # Margin around the extent: 10% of it, with a floor in metres for very small
  # geometries. EPSG:3857 units are metres, so a plain addition replaces turf's
  # geodesic buffer.
  MARGIN_RATIO = 0.1
  MIN_MARGIN = 20

  # Everything the usager drew — areas, lines and points alike — is rendered in
  # one colour over a dark casing. The interface uses red for areas and points
  # and dark blue for lines, but it draws them on a light vector basemap; here
  # they land on an aerial photo, where both drown in water, woodland and
  # shadow. Cadastre and RPG parcels keep the green of the interface: they come
  # from a référentiel, and staying distinct from the hand-drawn geometry is
  # exactly what tells the two apart.
  SELECTION_COLOR = '#FFD400'
  CASING_COLOR = '#1F1A00'
  # Added on each side of the stroke it sits under.
  CASING_EXTRA_WIDTH = 3

  STYLES = {
    'selection_utilisateur' => {
      fill: SELECTION_COLOR, fill_opacity: 0.35, stroke: SELECTION_COLOR, stroke_width: 4, casing: CASING_COLOR,
    },
    'cadastre' => {
      fill: '#018100', fill_opacity: 0.7, stroke: '#018100', stroke_width: 2,
    },
    'rpg' => {
      fill: '#018100', fill_opacity: 0.7, stroke: '#018100', stroke_width: 2,
    },
  }.freeze
  DEFAULT_STYLE = STYLES.fetch('selection_utilisateur')
  POINT_RADIUS_PX = 8

  ATTRIBUTION = '© IGN — Géoplateforme'

  class EmptyGeometryError < StandardError; end

  def self.render(feature_collection, size: DEFAULT_SIZE)
    new(feature_collection, size:).render
  end

  def initialize(feature_collection, size: DEFAULT_SIZE)
    @feature_collection = feature_collection.deep_symbolize_keys
    @size = size
  end

  def render
    raise EmptyGeometryError if features.empty?

    layers = APIIgn::API.fetch_wms_layers(bbox:, size: @size)
    composite(layers, svg)
  end

  private

  attr_reader :size

  def features
    @features ||= Array(@feature_collection[:features]).filter { it[:geometry].present? }
  end

  # --- Projection EPSG:4326 -> EPSG:3857 -------------------------------------

  EARTH_RADIUS = 6378137.0
  # Latitude beyond which the Mercator projection diverges.
  MAX_LATITUDE = 85.05112878

  def project(coordinates)
    lon, lat = coordinates
    lat = lat.to_f.clamp(-MAX_LATITUDE, MAX_LATITUDE)
    [
      EARTH_RADIUS * lon.to_f * Math::PI / 180,
      EARTH_RADIUS * Math.log(Math.tan(Math::PI / 4 + (lat * Math::PI / 180) / 2)),
    ]
  end

  # --- Extent ----------------------------------------------------------------

  # Square projected extent, as [min_x, min_y, max_x, max_y].
  def bbox
    @bbox ||= begin
      points = features.flat_map { each_coordinate(it[:geometry]).map { |coord| project(coord) } }
      # No usable coordinate: a type `each_coordinate` cannot walk
      # (GeometryCollection, which the GeoJSON schema accepts). Without this,
      # computing the centre fails with a NoMethodError, which ApplicationJob
      # would retry 25 times for a geometry that will never be renderable.
      raise EmptyGeometryError if points.empty?

      xs = points.map(&:first)
      ys = points.map(&:last)
      min_x, max_x = xs.minmax
      min_y, max_y = ys.minmax

      center_x = (min_x + max_x) / 2
      center_y = (min_y + max_y) / 2
      half = [max_x - min_x, max_y - min_y].max / 2
      half = POINT_RADIUS if half.zero?
      half += [half * MARGIN_RATIO, MIN_MARGIN].max

      [center_x - half, center_y - half, center_x + half, center_y + half]
    end
  end

  def each_coordinate(geometry)
    case geometry[:type]
    when 'Point' then [geometry[:coordinates]]
    when 'MultiPoint', 'LineString' then geometry[:coordinates]
    when 'MultiLineString', 'Polygon' then geometry[:coordinates].flatten(1)
    when 'MultiPolygon' then geometry[:coordinates].flatten(2)
    else []
    end
  end

  # --- SVG generation --------------------------------------------------------

  def to_pixel(coordinates)
    min_x, _min_y, _max_x, max_y = bbox
    scale = size / (bbox[2] - bbox[0])
    x, y = project(coordinates)
    [((x - min_x) * scale).round(2), ((max_y - y) * scale).round(2)]
  end

  def svg
    shapes = features.flat_map { shapes_for(it) }.join("\n")

    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="#{size}" height="#{size}">
      #{shapes}
      #{attribution}
      </svg>
    SVG
  end

  def shapes_for(feature)
    style = STYLES.fetch(feature.dig(:properties, :source).to_s, DEFAULT_STYLE)
    geometry = feature[:geometry]

    case geometry[:type]
    when 'Point'
      [circle(geometry[:coordinates], style)]
    when 'MultiPoint'
      geometry[:coordinates].map { circle(it, style) }
    when 'LineString'
      [line(geometry[:coordinates], style)]
    when 'MultiLineString'
      geometry[:coordinates].map { line(it, style) }
    when 'Polygon'
      [polygon(geometry[:coordinates], style)]
    when 'MultiPolygon'
      geometry[:coordinates].map { polygon(it, style) }
    else
      []
    end
  end

  # The disc is opaque and the casing becomes its ring: a stroke on a circle is
  # centred on the edge, so the wider-path trick the other shapes need does not
  # apply here.
  def circle(coordinates, style)
    x, y = to_pixel(coordinates)
    %(<circle cx="#{x}" cy="#{y}" r="#{POINT_RADIUS_PX}" fill="#{style[:fill]}" stroke="#{style[:casing] || style[:stroke]}" stroke-width="#{CASING_EXTRA_WIDTH}" />)
  end

  def line(coordinates, style)
    data = path_data(coordinates)

    casing(data, style) + %(<path d="#{data}" fill="none" #{stroke_attributes(style)} />)
  end

  # `fill-rule="evenodd"` hollows out the polygon's inner rings (holes).
  def polygon(rings, style)
    data = rings.map { "#{path_data(it)} Z" }.join(' ')

    casing(data, style) + %(<path d="#{data}" fill="#{style[:fill]}" fill-opacity="#{style[:fill_opacity]}" fill-rule="evenodd" #{stroke_attributes(style)} />)
  end

  # A wider dark path, drawn under the stroke. SVG has no line casing, and
  # without one a single-colour mark disappears into water, woodland or shadow.
  def casing(data, style)
    return '' if style[:casing].blank?

    %(<path d="#{data}" fill="none" stroke="#{style[:casing]}" stroke-width="#{style[:stroke_width] + CASING_EXTRA_WIDTH}" stroke-linejoin="round" stroke-linecap="round" />\n)
  end

  def stroke_attributes(style)
    %(stroke="#{style[:stroke]}" stroke-width="#{style[:stroke_width]}" stroke-linejoin="round" stroke-linecap="round")
  end

  def path_data(coordinates)
    "M #{coordinates.map { to_pixel(it).join(',') }.join(' L ')}"
  end

  # Géoplateforme requires the source to be credited; it is burnt into the
  # image, which travels on its own (PDF, export).
  def attribution
    <<~SVG.squish
      <text x="#{size - 8}" y="#{size - 8}" text-anchor="end" font-family="sans-serif"
        font-size="14" fill="#FFFFFF" stroke="#000000" stroke-width="0.5"
        paint-order="stroke">#{ATTRIBUTION}</text>
    SVG
  end

  # --- Compositing -----------------------------------------------------------

  def composite(layers, svg)
    require "vips"

    images = layers.map { Vips::Image.new_from_buffer(it, '') }
    images << Vips::Image.new_from_buffer(svg, '', dpi: 72)
    images = images.map { it.has_alpha? ? it : it.bandjoin(255) }

    images
      .reduce { |base, overlay| base.composite2(overlay, :over) }
      .flatten(background: [255, 255, 255])
      .write_to_buffer('.jpg[Q=80]')
  end
end
