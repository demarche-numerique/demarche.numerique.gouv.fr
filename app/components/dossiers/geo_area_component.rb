# frozen_string_literal: true

class Dossiers::GeoAreaComponent < ApplicationComponent
  attr_reader :geo_area, :editing

  def initialize(geo_area:, editing:)
    @geo_area, @editing = geo_area, editing
  end
end
