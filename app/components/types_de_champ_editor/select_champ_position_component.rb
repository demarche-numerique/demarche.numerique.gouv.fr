# frozen_string_literal: true

class TypesDeChampEditor::SelectChampPositionComponent < ApplicationComponent
  def initialize(revision:, coordinate:)
    @revision = revision
    @coordinate = coordinate
  end

  def options
    [[t(".move_after"), @coordinate.stable_id]]
  end

  def describedby_id
    dom_id(@coordinate, :move_and_morph)
  end
end
