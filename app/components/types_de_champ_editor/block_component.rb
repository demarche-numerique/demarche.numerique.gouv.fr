# frozen_string_literal: true

class TypesDeChampEditor::BlockComponent < ApplicationComponent
  def initialize(block:, coordinates:)
    @block = block
    @coordinates = coordinates
  end

  private

  def block_id
    dom_id(@block, :types_de_champ_editor_block)
  end
end
