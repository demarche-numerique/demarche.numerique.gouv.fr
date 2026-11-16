# frozen_string_literal: true

# A level of a branch tree: the answers to one source champ as a list, each
# holding the next level or, as a leaf, the champs displayed.
class Procedure::BranchTreeNodeComponent < ApplicationComponent
  def initialize(revision:, node:, coordinates: nil)
    @revision = revision
    @node = node
    @coordinates = coordinates || revision.public_revision_type_de_champs.index_by(&:stable_id)
  end

  private

  attr_reader :revision, :node, :coordinates

  # « Situation : Salarié, Retraité »
  def label(child)
    safe_join([tag.span(child.source.libelle, class: 'fr-text--bold'), ' : ', child.to_s])
  end

  def displayed(leaf)
    coordinates.each_value.filter_map { it.type_de_champ if leaf.visible.include?(it.stable_id) }
  end

  def champ_path(tdc)
    champs_admin_procedure_path(revision.procedure, anchor: dom_id(coordinates.fetch(tdc.stable_id), :type_de_champ_editor))
  end
end
