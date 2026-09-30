# frozen_string_literal: true

class GeoArea < ApplicationRecord
  include ActionView::Helpers::NumberHelper
  belongs_to :champ_data, class_name: 'ChampData', foreign_key: :champ_id, optional: false, inverse_of: :geo_areas
  before_create :set_default_uuid
  after_create_commit :fetch_cadastre_real_geometry, if: -> { cadastre? && cadastre_state.nil? }

  enum :cadastre_state, %w[cadastre_fetched cadastre_error].index_by(&:itself)

  scope :pending_cadastre, -> { where(source: :cadastre, cadastre_state: nil) }

  # FIXME: once geo_areas are migrated to not use YAML serialization we can enable store_accessor
  # store_accessor :properties, :description, :numero, :section
  def properties
    value = read_attribute(:properties)
    if value.is_a? String
      ActiveRecord::Coders::YAMLColumn.new(:properties).load(value)
    else
      value || {}
    end
  end

  def description
    properties['description']
  end

  def numero
    if rpg?
      properties['id']
    else
      properties['numero']
    end
  end

  def section
    properties['section']
  end

  def filename
    properties['filename']
  end

  enum :source, {
    cadastre: 'cadastre',
    selection_utilisateur: 'selection_utilisateur',
    rpg: 'rpg',
  }

  validates :geometry, geo_json: true, allow_nil: false

  def to_feature
    {
      type: 'Feature',
      geometry: geometry.deep_symbolize_keys,
      properties: extra_properties.merge(
        source: source,
        area: area,
        length: length,
        description: description,
        filename: filename,
        id: uuid,
        champ_label: champ_data.libelle,
        champ_id: champ_data.stable_id,
        champ_row: champ_data.row_id,
        champ_private: champ_data.private?,
        dossier_id: champ_data.dossier_id
      ).compact,
    }
  end

  def label
    case source
    when GeoArea.sources.fetch(:cadastre), GeoArea.sources.fetch(:rpg)
      parcelle_label
    when GeoArea.sources.fetch(:selection_utilisateur)
      if polygon?
        if area > 0
          I18n.t("area", scope: 'geo_area.label', area: number_with_delimiter(area))
        else
          I18n.t("area_unknown", scope: 'geo_area.label')
        end
      elsif line?
        if length > 0
          I18n.t("line", scope: 'geo_area.label', length: number_with_delimiter(length))
        else
          I18n.t("line_unknown", scope: 'geo_area.label')
        end
      elsif point?
        I18n.t("point", scope: 'geo_area.label', location: location)
      end
    end
  end

  def area
    if polygon?
      GeojsonService.area(geometry.deep_symbolize_keys).round(1)
    end
  end

  def length
    if line?
      GeojsonService.length(geometry.deep_symbolize_keys).round(1)
    end
  end

  def location
    if point?
      coordinates = geometry['coordinates'][0..1]
      begin
        Geo::Coord.new(*coordinates.reverse).to_s
      rescue ArgumentError
        # out of range coordinates (e.g. projected meters imported from a bad geojson)
        coordinates.join(', ')
      end
    end
  end

  def line?
    geometry['type'] == 'LineString'
  end

  def polygon?
    geometry['type'] == 'Polygon'
  end

  def point?
    geometry['type'] == 'Point'
  end

  def legacy_cadastre?
    cadastre? && properties['surface_intersection'].present?
  end

  def cadastre?
    source == GeoArea.sources.fetch(:cadastre)
  end

  def rpg?
    source == GeoArea.sources.fetch(:rpg)
  end

  def extra_properties
    if cadastre?
      {
        cid: cid,
        numero: numero,
        section: section,
        prefixe: prefixe,
        commune: commune,
        surface: surface,
      }
    elsif rpg?
      {
        cid:,
      }
    else
      {}
    end
  end

  def code_dep
    if legacy_cadastre?
      properties['code_dep']
    else
      properties['commune'][0..1]
    end
  end

  def code_com
    if legacy_cadastre?
      properties['code_com']
    else
      properties['commune'][2...commune.size]
    end
  end

  def nom_com
    if legacy_cadastre?
      properties['nom_com']
    else
      ''
    end
  end

  def surface_intersection
    if legacy_cadastre?
      properties['surface_intersection']
    else
      ''
    end
  end

  def feuille
    if legacy_cadastre?
      properties['feuille']
    else
      1
    end
  end

  def code_arr
    prefixe
  end

  # see: https://gist.github.com/ThomasG77/a9b39677d302e2405c18cfe9bc8e462b
  def parcelle_id
    if legacy_cadastre?
      code_insee = "#{properties['code_dep']}#{properties['code_com']}"
      ancien_code = properties['code_arr']
      section = properties['section'].rjust(2, '0')
      numero = properties['numero'].rjust(4, '0')
      [code_insee, ancien_code, section, numero].join('')
    else
      properties["id"]
    end
  end

  def surface_parcelle
    surface
  end

  def surface
    api_surface = if legacy_cadastre?
      properties['surface_parcelle']
    else
      properties['contenance']
    end
    api_surface ? api_surface : area
  end

  def prefixe
    if legacy_cadastre?
      properties['code_arr']
    else
      properties['prefixe']
    end
  end

  def commune
    if legacy_cadastre?
      "#{properties['code_dep']}#{properties['code_com']}"
    else
      properties['commune']
    end
  end

  def cid
    if legacy_cadastre?
      "#{code_dep}#{code_com}#{code_arr}#{section}#{numero}"
    else
      properties['id']
    end
  end

  private

  # What it knows of the parcelle and nothing else, as the map tells it on
  # hover (Map/parcelle.ts).
  def parcelle_label
    parts = [
      parcelle_numero_label,
      parcelle_feuille_label,
      parcelle_surface_label,
      (I18n.t('geo_area.label.commune', commune:) if commune.present?),
    ]
    parts.compact.join(' – ')
  end

  def parcelle_numero_label
    numero = self.numero.presence || cid
    if numero.present?
      I18n.t('geo_area.label.parcelle', numero:)
    else
      I18n.t(source, scope: 'activerecord.attributes.geo_area.source')
    end
  end

  def parcelle_feuille_label
    if section.present?
      I18n.t('geo_area.label.feuille', feuille: [prefixe, section].compact_blank.join("\u00A0"))
    end
  end

  def parcelle_surface_label
    if surface.nil?
      nil
    elsif rpg?
      hectares = (surface / 10_000.0).round(2)
      # 2 rather than 2,0
      hectares = hectares.to_i if hectares == hectares.to_i
      I18n.t('geo_area.label.surface_hectares', surface: number_with_delimiter(hectares))
    else
      # a legacy surface may be a string
      I18n.t('geo_area.label.surface_m2', surface: number_with_delimiter(surface.to_f.round))
    end
  end

  def fetch_cadastre_real_geometry
    FetchCadastreRealGeometryJob.perform_later(self)
  end

  def set_default_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
