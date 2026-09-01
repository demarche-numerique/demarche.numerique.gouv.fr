# frozen_string_literal: true

# Enumerates the ways a form can unfold: which champs are displayed for which
# fillings of the champs the conditions target.
#
# Conditional champs linked by the champs they target form clusters; clusters
# share no source, so their branches are independent of one another. A source
# is a champ as an atom reads it, its value or one of its columns; within a
# cluster, every source is split into the regions its atoms tell apart (see
# Logic::Domain#regions), plus blank when the champ is optional; a branch is a
# choice of one region per source, and lists the champs it displays. A champ
# is displayed when its condition holds, an atom on a champ that is itself
# hidden, blank or gone from the form being false.
#
# A cluster with more branches than MAX_BRANCHES is left unenumerated
# (`branches` is nil): callers fall back to bounds.
class Logic::Branches
  MAX_BRANCHES = 10_000

  # `term` is the Logic::ChampValue or Logic::ChampColumnValue the atoms use.
  Source = Data.define(:type_de_champ, :term) do
    def mandatory? = type_de_champ.mandatory?

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

  # In form order, the columns of a champ in the order the atoms read them.
  def sources(members)
    terms = members.flat_map { it.condition.terms }.filter(&:constraining?).map(&:left).uniq

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
    domain, atoms = domain_and_atoms(source, members)

    count = domain ? domain.max_regions(atoms) : 0

    source.mandatory? ? [count, 1].max : count + 1
  end

  def regions_of(source, members)
    domain, atoms = domain_and_atoms(source, members)

    regions = domain ? domain.regions(atoms) : []
    regions << Logic::Domain::Blank if regions.empty? || !source.mandatory?

    regions
  end

  # The domain of the source (nil when no condition can reason about it) and
  # the atoms the members put on it, computed once per source.
  def domain_and_atoms(source, members)
    @domain_and_atoms ||= {}
    @domain_and_atoms[source.term] ||= [
      source.term.domain(@type_de_champs),
      members.flat_map { atoms_on(it.condition, source.term) },
    ]
  end

  def atoms_on(condition, term)
    condition.terms
      .filter { it.constraining? && it.left == term }
      .map { [it.class, it.right.value] }
  end

  def enumerate(regions, members)
    terms = regions.keys

    regions.values.reduce([[]]) { |acc, alternatives| acc.product(alternatives).map(&:flatten) }.map do |choice|
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
      if term.constraining?
        stable_id = term.left.stable_id
        source = @by_stable_id[stable_id]
        displayed = !source.nil? && (!source.condition? || visible.include?(stable_id))

        displayed && !assignment.fetch(term.left).restrict(term.class, term.right.value).empty?
      else
        term.compute([]) == true
      end
    end
  end
end
