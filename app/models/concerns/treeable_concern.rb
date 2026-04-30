# frozen_string_literal: true

module TreeableConcern
  extend ActiveSupport::Concern

  MAX_DEPTH = 6 # deepest level for header_sections is 3.
  # but a repetition can be nested an header_section, so 3+3=6=MAX_DEPTH

  # as we progress in the list of ordered types_de_champ
  #   we keep a reference to each level of nesting (walk)
  # when we encounter an header_section, it depends of its own depth of nesting minus 1, ie:
  #   h1 belongs to prior (rooted_tree)
  #   h2 belongs to prior h1
  #   h3 belongs to prior h2
  #   h1 belongs to prior (rooted_tree)
  # then, each and every types_de_champ which are not an header_section
  #   are added to the current_tree
  # given a root_depth at 0, we build a full tree
  # given a root_depth > 0, we build a partial tree (aka, a repetition)
  def to_tree(types_de_champ:)
    rooted_tree = []
    walk = Array.new(MAX_DEPTH)
    walk[0] = rooted_tree
    current_tree = rooted_tree

    types_de_champ.each do |type_de_champ|
      if type_de_champ.header_section?
        new_tree = [type_de_champ]
        parent_level = type_de_champ.header_section_level_value - 1
        parent_level -= 1 while parent_level > 0 && walk[parent_level].nil?
        walk[parent_level].push(new_tree)
        current_tree = walk[type_de_champ.header_section_level_value] = new_tree
      else
        current_tree.push(type_de_champ)
      end
    end
    rooted_tree
  end
end
