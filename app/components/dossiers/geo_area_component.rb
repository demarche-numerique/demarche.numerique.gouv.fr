# frozen_string_literal: true

class Dossiers::GeoAreaComponent < ApplicationComponent
  attr_reader :geo_area, :editing

  def initialize(geo_area:, editing:)
    @geo_area, @editing = geo_area, editing
  end

  # The id of the geojson feature drawn on the map.
  def feature_id = (geo_area.uuid || geo_area.id).to_s
end
