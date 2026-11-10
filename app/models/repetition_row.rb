# frozen_string_literal: true

# One row of a repetition champ: the row id, its 1-based position, and the
# champs it holds, laid out by the dossier's ChampLayout.
class RepetitionRow
  include ChampContainerConcern

  attr_reader :id, :index, :repetition, :children

  def initialize(id:, index:, repetition:)
    @id = id
    @index = index
    @repetition = repetition
  end

  # Set once, by the layout that built the row.
  def lay_out(children:)
    @children = children.freeze
    self
  end

  def flat_children
    @flat_children ||= super
  end
end
