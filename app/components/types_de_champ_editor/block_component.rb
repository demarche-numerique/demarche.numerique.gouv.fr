# frozen_string_literal: true

class TypesDeChampEditor::BlockComponent < ApplicationComponent
  # block: the revision, or a repetition and what it holds
  def initialize(block:, type_de_champs:)
    @block = block
    @type_de_champs = type_de_champs
  end

  private

  def block_id
    dom_id(@block, :types_de_champ_editor_block)
  end
end
