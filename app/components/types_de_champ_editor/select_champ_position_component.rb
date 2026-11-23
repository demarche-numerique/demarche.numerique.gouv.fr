# frozen_string_literal: true

# The place to move a type de champ to. Its options come from the template of
# its block when it takes the focus (SelectChampTemplatePositionComponent).
class TypesDeChampEditor::SelectChampPositionComponent < ApplicationComponent
  def initialize(type_de_champ:)
    @type_de_champ = type_de_champ
  end

  # its own line in the list of places, disabled there
  def place
    "#{@type_de_champ.header_section? ? 'first' : 'after'}:#{@type_de_champ.stable_id}"
  end

  def options
    [[t(".move_after"), place]]
  end

  def describedby_id
    dom_id(@type_de_champ, :move_to_place)
  end
end
