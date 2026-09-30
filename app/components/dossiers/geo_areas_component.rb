# frozen_string_literal: true

class Dossiers::GeoAreasComponent < ApplicationComponent
  attr_reader :champ, :editing

  def initialize(champ:, editing:)
    @champ, @editing = champ, editing
  end
end
