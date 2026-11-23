# frozen_string_literal: true

# The list of what the form, the annotations, a repetition or a header section
# hold.
class TypesDeChampEditor::BlockComponent < ApplicationComponent
  # block: the revision, or the type de champ holding the ones given
  def initialize(block:, type_de_champs:, focused_stable_id: nil, errors: {})
    @block = block
    @type_de_champs = type_de_champs
    @focused_stable_id = focused_stable_id
    @errors = errors
  end

  private

  def block_id
    dom_id(@block, :types_de_champ_editor_block)
  end

  # The places a type de champ may move to are listed once for the form, the
  # annotations or a repetition: it never leaves them, and the header sections
  # are within.
  def position_template
    return if @block.is_a?(TypeDeChamp) && !@block.repetition?

    flat_type_de_champs = @block.is_a?(TypeDeChamp) ? @block.flat_children : @type_de_champs.first&.flat_siblings.to_a

    TypesDeChampEditor::SelectChampTemplatePositionComponent.new(block: @block, type_de_champs: flat_type_de_champs)
  end
end
