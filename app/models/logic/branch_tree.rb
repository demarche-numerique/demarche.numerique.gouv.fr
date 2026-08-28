# frozen_string_literal: true

# Folds the branches of a cluster (see Logic::Branches) into the tree an
# admin can read: one level per source champ in form order, answers that
# lead to the very same rest of the form merged into one node, and levels
# where the answer changes nothing left out.
#
#   Situation : Salarié
#     Âge : 17 ou moins            → Autorisation parentale, Contrat
#     Âge : 18 ou plus, non renseigné → Contrat
#   Situation : Indépendant, Retraité → Justificatif de revenus
#
# A tree with more leaves than MAX_LEAVES is not built (`root` is nil): it
# would not be read either.
class Logic::BranchTree
  MAX_LEAVES = 100

  # A node is one answer (or several, merged) to a source champ, holding
  # either the next source's nodes or, as a leaf, the champs displayed.
  Node = Data.define(:source, :regions, :children, :visible) do
    def self.leaf(visible) = new(source: nil, regions: [], children: [], visible:)

    def self.branching(children) = new(source: nil, regions: [], children:, visible: nil)

    def leaf? = children.empty?

    def outcome = [children, visible]

    def leaves = leaf? ? [self] : children.flat_map(&:leaves)

    # « Salarié, Retraité » or, when the domains list values themselves,
    # « avec A ou avec B, sans A »
    def to_s
      described = regions.map { it.to_s(source.type_de_champ) }

      described.join(described.any? { it.include?(', ') } ? I18n.t('logic.domain.or') : ', ')
    end
  end

  attr_reader :cluster

  def initialize(cluster)
    @cluster = cluster
  end

  def capped? = root.nil?

  def root
    return @root if defined?(@root)

    @root = @cluster.capped? ? nil : build(@cluster.branches, @cluster.sources).then { it.leaves.size <= MAX_LEAVES ? it : nil }
  end

  # Members no branch displays: unreachable through the cluster as a whole.
  def never_displayed
    return [] if @cluster.capped?

    displayed = @cluster.branches.map(&:visible).reduce(Set.new, :|)

    @cluster.members.reject { displayed.include?(it.stable_id) }
  end

  private

  def build(branches, sources)
    return Node.leaf(branches.first.visible) if sources.empty?

    source, *rest = sources

    children = branches
      .group_by { it.regions.fetch(source.term) }
      .map { |region, group| build(group, rest).with(source:, regions: [region]) }
      .then { merge(it) }
      .then { sort(it) }

    # A single child means the source does not branch here: its subtree
    # stands in for the level.
    children.size == 1 ? children.first.with(source: nil, regions: []) : Node.branching(children)
  end

  # Siblings with the same outcome become one node, their regions merged
  # when the domains can tell the union, listed otherwise.
  def merge(nodes)
    nodes.each_with_object([]) do |node, merged|
      twin = merged.find { it.outcome == node.outcome }

      if twin
        merged[merged.index(twin)] = twin.with(regions: add_regions(twin.regions, node.regions))
      else
        merged << node
      end
    end
  end

  def add_regions(regions, added)
    added.reduce(regions) do |acc, region|
      index = acc.index { it.union(region) }

      index ? acc.dup.tap { it[index] = it[index].union(region) } : acc + [region]
    end
  end

  # By the domains' own order (numbers ascending, blank last), ties as
  # enumerated.
  def sort(nodes)
    nodes.sort_by.with_index { |node, index| [*node.regions.first.sort_key, index] }
  end
end
