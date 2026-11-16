# frozen_string_literal: true

# One accordion per cluster of conditional champs, holding the tree of what
# the form displays for which answers (see Logic::BranchTree).
class Procedure::BranchTreesComponent < ApplicationComponent
  def initialize(revision:, branch_trees:)
    @revision = revision
    @branch_trees = branch_trees
  end

  private

  attr_reader :revision, :branch_trees

  # Named after its sources, or after its members when their conditions only
  # target champs gone from the form.
  def title(tree)
    sources = tree.cluster.sources.presence

    t(sources ? '.title' : '.title_without_source', champs: (sources || tree.cluster.members).map { "« #{it.libelle} »" }.to_sentence)
  end

  def never_displayed_libelles(tree)
    tree.never_displayed.map { "« #{it.libelle} »" }.to_sentence
  end

  def node_component(tree)
    Procedure::BranchTreeNodeComponent.new(revision:, node: tree.root)
  end
end
