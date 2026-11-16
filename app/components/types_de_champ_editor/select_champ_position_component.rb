# frozen_string_literal: true

class TypesDeChampEditor::SelectChampPositionComponent < ApplicationComponent
  def initialize(type_de_champ:)
    @type_de_champ = type_de_champ
  end

  def options
    [[t(".move_after"), @type_de_champ.stable_id]]
  end

  def describedby_id
    dom_id(@type_de_champ, :move_and_morph)
  end
end
