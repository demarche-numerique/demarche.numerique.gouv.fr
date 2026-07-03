# frozen_string_literal: true

class Champs::CarteChamp < Champ
  # Default map location. Center of the World, ahm, France...
  DEFAULT_LON = 2.428462
  DEFAULT_LAT = 46.538192

  def legend_label?
    true
  end

  def html_label?
    false
  end

  # We are not using scopes here as we want to access
  # the following collections on unsaved records.
  def cadastres
    if cadastres?
      geo_areas.filter(&:cadastre?)
    else
      []
    end
  end

  def rpgs
    if rpg?
      geo_areas.filter(&:rpg?)
    else
      []
    end
  end

  def selections_utilisateur
    geo_areas.filter do |area|
      area.source == GeoArea.sources.fetch(:selection_utilisateur)
    end
  end

  def cadastres?
    type_de_champ.layer_enabled?(:cadastres)
  end

  def rpg?
    type_de_champ.layer_enabled?(:rpg)
  end

  def optional_layers
    type_de_champ.carte_optional_layers
  end

  def render_options
    { layers: optional_layers }
  end

  def position
    if dossier.present?
      dossier.geo_position
    else
      lon = DEFAULT_LON.to_s
      lat = DEFAULT_LAT.to_s
      zoom = "13"

      { lon: lon, lat: lat, zoom: zoom }
    end
  end

  def bounding_box
    if geo_areas.present?
      GeojsonService.bbox(type: 'FeatureCollection', features: geo_areas.map(&:to_feature))
    elsif dossier.present?
      point = dossier.geo_position
      GeojsonService.bbox(type: 'Feature', geometry: { type: 'Point', coordinates: [point[:lon], point[:lat]] })
    else
      GeojsonService.bbox(type: 'Feature', geometry: { type: 'Point', coordinates: [DEFAULT_LON, DEFAULT_LAT] })
    end
  end

  def to_feature_collection
    {
      type: 'FeatureCollection',
      id: stable_id,
      bbox: bounding_box,
      features: geo_areas.map(&:to_feature),
    }
  end

  def geometry?
    geo_areas.present?
  end

  def selection_utilisateur_legacy_geo_area
    geometry = selection_utilisateur_legacy_geometry
    if geometry.present?
      GeoArea.new(
        source: GeoArea.sources.fetch(:selection_utilisateur),
        geometry: geometry
      )
    end
  end

  private

  def selection_utilisateur_legacy_geometry
    if selections_utilisateur.present?
      {
        type: 'MultiPolygon',
        coordinates: selections_utilisateur.filter do |selection_utilisateur|
          selection_utilisateur.geometry['type'] == 'Polygon'
        end.map do |selection_utilisateur|
          selection_utilisateur.geometry['coordinates']
        end,
      }
    else
      nil
    end
  end
end
