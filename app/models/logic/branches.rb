# frozen_string_literal: true

# Enumerates the ways a form can unfold: which champs are displayed for which
# fillings of the champs the conditions target.
#
# Conditional champs linked by the champs they target form clusters; clusters
# share no source, so their branches are independent of one another. A source
# is a champ as an comparison reads it, its value or one of its columns; within a
# cluster, every source is split into the regions its comparisons tell apart (see
# Logic::PossibleValues#regions), plus blank when the champ can be left so; a branch
# is a choice of one region per source, and lists the champs it displays. A champ
# is displayed when its condition holds, a comparison on a champ that is itself
# hidden, blank or gone from the form being false, as is one Logic::PossibleValues
# cannot interpret (still being written, or comparing two champs).
#
# A cluster with more branches than MAX_BRANCHES is left unenumerated
# (`branches` is nil): callers fall back to bounds.
class Logic::Branches
  MAX_BRANCHES = 10_000

  # `term` is the Logic::ChampValue or Logic::ChampColumnValue the comparisons use.
  Source = Data.define(:type_de_champ, :term) do
    # An optional champ can be left blank, except a checkbox: left alone, it
    # is saved unchecked, as `false`.
    def blankable? = !type_de_champ.mandatory? && !type_de_champ.checkbox?

    def libelle = term.to_s([type_de_champ])
  end

  # `regions` maps every source term of the cluster to a region.
  Branch = Data.define(:regions, :visible) do
    def visible?(type_de_champ) = visible.include?(type_de_champ.stable_id)
  end

  Cluster = Data.define(:sources, :members, :branches) do
    def capped? = branches.nil?
  end

  def initialize(type_de_champs)
    @type_de_champs = type_de_champs
    @by_stable_id = type_de_champs.index_by(&:stable_id)
    @conditional = conditional.map(&:stable_id).to_set
    @holding = Hash.new { |holding, term| holding[term] = {}.compare_by_identity }
  end

  def clusters
    @clusters ||= components.map { cluster(it) }
  end

  private

  def conditional = @type_de_champs.filter(&:condition?)

  # Connected components of the graph linking each conditional champ to the
  # champs its condition targets.
  def components
    parent = {}
    find = -> (id) { parent[id] == id || parent[id].nil? ? (parent[id] ||= id) : (parent[id] = find.(parent[id])) }
    union = -> (a, b) { parent[find.(a)] = find.(b) }

    conditional.each do |tdc|
      tdc.condition.sources.each { union.(tdc.stable_id, it) }
    end

    parent.keys.group_by { find.(it) }.values.map { |ids| ids.filter_map { @by_stable_id[it] } }
  end

  def cluster(type_de_champs)
    members = ordered(type_de_champs.filter(&:condition?))
    sources = sources(members)

    Cluster.new(sources:, members:, branches: branches(sources, members))
  end

  # In form order, the columns of a champ in the order the comparisons read them.
  def sources(members)
    terms = members.flat_map { it.condition.terms }.filter(&:checkable?).map(&:left).uniq

    @type_de_champs.flat_map do |type_de_champ|
      terms.filter { it.stable_id == type_de_champ.stable_id }.map { Source.new(type_de_champ:, term: it) }
    end
  end

  # Regions are bounded before being built: a multiple choice has one per
  # subset of its mentioned options.
  def branches(sources, members)
    return if sources.map { max_regions_of(it, members) }.reduce(1, :*) > MAX_BRANCHES

    enumerate(sources.to_h { [it.term, regions_of(it, members)] }, members)
  end

  def max_regions_of(source, members)
    values, comparisons = values_and_comparisons(source, members)

    count = values ? values.max_regions(comparisons.map { operator_and_value(it) }) : 0

    source.blankable? ? count + 1 : [count, 1].max
  end

  # A region is cut so that a comparison holds on all of it or on none of it:
  # which comparisons hold is settled once per region, and looked up per branch.
  def regions_of(source, members)
    values, comparisons = values_and_comparisons(source, members)

    regions = values ? values.regions(comparisons.map { operator_and_value(it) }) : []
    regions << Logic::PossibleValues::Blank if regions.empty? || source.blankable?

    regions.each do |region|
      @holding[source.term][region] = comparisons.filter { !region.restrict(*operator_and_value(it)).empty? }.to_set
    end

    regions
  end

  # The values of the source (nil when no condition can reason about it) and
  # the comparisons the members put on it, computed once per source.
  def values_and_comparisons(source, members)
    @values_and_comparisons ||= {}
    @values_and_comparisons[source.term] ||= [
      source.term.possible_values(@type_de_champs),
      members.flat_map { it.condition.terms }.filter { it.checkable? && it.left == source.term }.uniq,
    ]
  end

  def operator_and_value(comparison) = [comparison.class, comparison.right.value]

  def enumerate(regions, members)
    terms = regions.keys
    choices = terms.empty? ? [[]] : regions.values.first.product(*regions.values.drop(1))

    choices.map do |choice|
      assignment = terms.zip(choice).to_h
      Branch.new(regions: assignment, visible: visible_in(assignment, members))
    end
  end

  # Members with the conditional champs they target before them, so that a
  # source is decided before its dependents whatever the form order (a draft
  # may have a source moved below them); members targeting each other keep
  # the form order.
  def ordered(members)
    remaining = members.dup
    ordered = []

    while remaining.any?
      pending = remaining.map(&:stable_id)
      ready = remaining.filter { |member| (member.condition.sources & pending).empty? }.presence || [remaining.first]

      ordered.concat(ready)
      remaining -= ready
    end

    ordered
  end

  # A source is displayed when unconditional or already found visible.
  def visible_in(assignment, members)
    members.each_with_object(Set.new) do |member, visible|
      visible << member.stable_id if holds?(member.condition, assignment, visible)
    end
  end

  def holds?(term, assignment, visible)
    case term
    when Logic::And then term.operands.all? { holds?(it, assignment, visible) }
    when Logic::Or then term.operands.any? { holds?(it, assignment, visible) }
    when Logic::EmptyOperator then true
    else
      term.checkable? && displayed?(term.left.stable_id, visible) && holds_in?(term, assignment.fetch(term.left))
    end
  end

  def displayed?(stable_id, visible)
    @by_stable_id.key?(stable_id) && (!@conditional.include?(stable_id) || visible.include?(stable_id))
  end

  def holds_in?(comparison, region) = @holding.fetch(comparison.left).fetch(region).include?(comparison)
end
