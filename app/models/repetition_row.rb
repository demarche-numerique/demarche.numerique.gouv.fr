# frozen_string_literal: true

# One row of a repetition champ: the row id, its 1-based position, the public
# id of the champ that prefilled it if any, and the champs it holds, laid out
# by the dossier's ChampLayout.
class RepetitionRow
  include ChampContainerConcern

  attr_reader :id, :index, :repetition, :prefilled_by, :children

  def initialize(id:, index:, repetition:, prefilled_by: nil)
    @id = id
    @index = index
    @repetition = repetition
    @prefilled_by = prefilled_by
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
