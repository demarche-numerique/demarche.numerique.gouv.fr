# frozen_string_literal: true

# What holds champs: a header section, the row of a repetition. `children` is
# what it directly holds — champs, and the header sections and repetitions
# holding the rest — as its type de champ is laid out in the revision.
module ChampContainerConcern
  # everything it holds in document order, whatever the depth: a repetition is
  # followed by the content of each of its rows
  def flat_children
    children.flat_map do |champ|
      if champ.repetition?
        [champ, *champ.rows.flat_map(&:flat_children)]
      elsif champ.header_section?
        [champ, *champ.flat_children]
      else
        champ
      end
    end
  end
end
