# frozen_string_literal: true

class Dossiers::GeoAreasComponent < ApplicationComponent
  attr_reader :champ, :editing, :legacy_editor

  # `legacy_editor`: the list of the editor on mapbox-gl-draw.
  def initialize(champ:, editing:, legacy_editor: false)
    @champ, @editing, @legacy_editor = champ, editing, legacy_editor
  end
end
