# frozen_string_literal: true

module TreeMakerConcern
  extend ActiveSupport::Concern

  def tree_it(coordinates)
    return [] if coordinates.blank?

    head, *tail = coordinates

    case head
    in header if head.header_section?
      children = tail.take_while { !same_or_shallower_level?(header, it) }
      rest = tail.drop(children.size)

      header.children = tree_it(children)

      [header] + tree_it(rest)

    in repetition if head.repetition?
      repetition.children = tree_it(repetition.revision_types_de_champ)

      [repetition] + tree_it(tail)

    else
      [head] + tree_it(tail)
    end
  end

  private

  def same_or_shallower_level?(header, el)
    el.header_section? &&
      el.type_de_champ.header_section_level_value <= header.type_de_champ.header_section_level_value
  end
end
