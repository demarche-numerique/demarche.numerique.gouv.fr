# frozen_string_literal: true

# The tree as an editor listing every block flat edits it: a header section
# holds nothing there, what follows it being its content up to the next header
# section of its level or above. Only a repetition holds anything.
#
# The tree does not know what its nodes are: the repetitions (a set) and the
# declared levels of the header sections (a hash) are given by type de champ id.
#
# FIXME: goes with that editor, once it edits the tree of sections (#14009).
module TypeDeChampTree::Flat
  def flatten(repetitions:)
    with(
      public_children: flattened(public_children, repetitions),
      private_children: flattened(private_children, repetitions)
    )
  end

  # The flat tree nested again. A header section nests in the nearest preceding
  # one of a lower level, however many levels are skipped in between (h1, h3:
  # the h3 is a child of the h1). What anything but a repetition holds is left
  # out: a repetition which took another type.
  def fold(levels:, repetitions:)
    with(
      public_children: folded(public_children, levels, repetitions),
      private_children: folded(private_children, levels, repetitions)
    )
  end

  private

  def flattened(nodes, repetitions)
    nodes.flat_map do |node|
      if repetitions.include?(node.type_de_champ_id)
        [node.with(children: flattened(node.children, repetitions))]
      else
        [node.with(children: []), *flattened(node.children, repetitions)]
      end
    end
  end

  def folded(siblings, levels, repetitions)
    section_children([*siblings], 0, levels, repetitions)
  end

  # consumes the siblings belonging to the open section, given by its declared
  # level (0 being no section at all), and leaves in the queue the header
  # section closing it. Levels compare as declared, not as nested: an h2
  # following a rooted h3 closes it.
  def section_children(queue, open_level, levels, repetitions)
    nodes = []

    while (node = queue.first)
      level = levels[node.type_de_champ_id]&.clamp(1..)
      break if level && level <= open_level

      queue.shift
      nodes << if level
        node.with(children: section_children(queue, level, levels, repetitions))
      elsif repetitions.include?(node.type_de_champ_id)
        node.with(children: folded(node.children, levels, repetitions))
      else
        node.with(children: [])
      end
    end

    nodes
  end
end
