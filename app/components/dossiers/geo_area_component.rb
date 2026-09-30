# frozen_string_literal: true

class Dossiers::GeoAreaComponent < ApplicationComponent
  attr_reader :geo_area, :editing, :legacy_editor

  def initialize(geo_area:, editing:, legacy_editor: false)
    @geo_area, @editing, @legacy_editor = geo_area, editing, legacy_editor
  end
end
