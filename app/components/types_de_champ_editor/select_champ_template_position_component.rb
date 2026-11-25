# frozen_string_literal: true

# The places of a block a type de champ may move to, as the form reads: first
# of the block, after another type de champ, or after a whole header section.
# The line of a header section is the place right after its title: first of
# what it holds. Listed once per block, and copied by the select of the type de
# champ to move (SelectChampPositionComponent).
class TypesDeChampEditor::SelectChampTemplatePositionComponent < ApplicationComponent
  # block: the revision or a repetition, type_de_champs: all it holds, in document order
  def initialize(block:, type_de_champs:)
    @block = block
    @type_de_champs = type_de_champs
  end

  def block_id
    dom_id(@block, :types_de_champ_editor_select_champ_template)
  end

  private

  # [label, place, the stable ids the place is within]: a type de champ does
  # not move within itself
  def places
    [[t(".first"), "first", []], *places_of(@type_de_champs.reject { it.parent&.header_section? })]
  end

  def places_of(type_de_champs, within = [])
    type_de_champs.flat_map do |type_de_champ|
      stable_id = type_de_champ.stable_id
      label = "#{indent(within)}#{numbers.fetch(stable_id)} - #{type_de_champ.libelle}"

      if type_de_champ.header_section?
        [
          [label, "first:#{stable_id}", [*within, stable_id]],
          *places_of(type_de_champ.children, [*within, stable_id]),
          ["#{indent(within)}#{t('.after_section', libelle: type_de_champ.libelle)}", "after:#{stable_id}", [*within, stable_id]],
        ]
      else
        [[label, "after:#{stable_id}", [*within, stable_id]]]
      end
    end
  end

  def numbers
    @numbers ||= @type_de_champs.each.with_index(1).to_h { |type_de_champ, number| [type_de_champ.stable_id, number] }
  end

  def indent(within) = "— " * within.size
end
