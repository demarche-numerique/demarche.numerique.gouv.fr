# frozen_string_literal: true

# Checks that a condition can be true for at least one way of filling the
# form: `a == 2 and a == 3` or `a > 3 and a < 2` never are, nor is
# `b == 'x' and a < 5` when `b` is only displayed if `a > 10`.
#
# The condition is walked as a disjunction of conjunctions, each conjunction
# folding its atoms (`champ <operator> constant`) into the domain of the champ
# they constrain (see Logic::Domain). A conjunction is satisfiable when no
# domain is empty; the condition when one of its conjunctions is. The walk
# stops at the first satisfiable conjunction, and does not extend a partial
# conjunction that already empties a domain.
#
# A blank or hidden champ makes every atom on it false, so an atom on a
# conditional champ is only ever true when the champ is displayed: the
# condition is also checked together with the display condition of each champ
# it targets (and of the champs those depend on, and so on).
class Logic::Satisfiability
  def initialize(type_de_champs)
    @type_de_champs = type_de_champs
    @display_conditions = {}
  end

  def errors(condition)
    contradictions(condition).presence || unreachable(condition)
  end

  private

  def contradictions(condition)
    failures = []

    return [] if satisfiable?([condition], [], failures)

    failures.map { |source, atoms| { type: :contradiction, stable_id: source.stable_id, atoms: } }.uniq
  end

  # Whether one conjunction of the pending terms, on top of the atoms
  # gathered so far, is satisfiable. Every domain emptied on the way is
  # collected in failures. Disjunctions are opened one at a time, starting
  # with one on a champ the atoms already constrain, so that a dead partial
  # conjunction is found before the alternatives multiply.
  def satisfiable?(pending, atoms, failures)
    ands, rest = pending.partition { it.is_a?(Logic::And) }
    ors, more = rest.partition { it.is_a?(Logic::Or) }
    atoms += more

    return satisfiable?(ands.flat_map(&:operands) + ors, atoms, failures) if ands.any?
    return false if !satisfiable_conjunction?(atoms, failures)
    return true if ors.empty?

    constrained = atoms.flat_map(&:sources)
    index = ors.index { it.sources.intersect?(constrained) } || 0
    branching = ors.delete_at(index)

    branching.operands.any? { satisfiable?([it, *ors], atoms, failures) }
  end

  def satisfiable_conjunction?(atoms, failures)
    unsatisfiable = unsatisfiable_variables(atoms)
    failures.concat(unsatisfiable)
    unsatisfiable.empty?
  end

  # The champs the condition targets may only be displayed under conditions of
  # their own: the condition is dead when no atom on them can hold together
  # with them. The culprits are the targeted champs whose display condition
  # alone kills it, or all of them when only their combination does.
  def unreachable(condition)
    sources = conditional_sources(condition)

    return [] if sources.empty?
    return [] if contradictions(guarded(condition, sources)).empty?

    culprits = sources.filter { contradictions(guarded(condition, [it])).any? }.presence || sources

    culprits.map { { type: :unreachable, stable_id: it.stable_id } }
  end

  # The condition with every atom on one of the sources holding only while
  # that champ is displayed. Guarding the atoms rather than the whole
  # condition keeps a disjunction alive through the branches that do not
  # need the champ.
  def guarded(term, sources)
    conjoin(*split(term, sources))
  end

  # [term, guards]: the term with its atoms guarded, except for the guards
  # every operand shares, returned to be applied once above (`(a and g) or
  # (b and g)` is `(a or b) and g`), so that a chain of display conditions
  # stays flat and cheap to search.
  def split(term, sources)
    case term
    when Logic::And, Logic::Or
      parts = term.operands.map { split(it, sources) }
      shared = parts.map(&:last).reduce(:&) || []

      [term.class.new(parts.map { |operand, guards| conjoin(operand, guards - shared) }), shared]
    else
      [term, sources.filter { term.sources.include?(it.stable_id) }.filter_map { display_condition(it) }]
    end
  end

  def conjoin(term, guards) = guards.empty? ? term : Logic::And.new([term, *guards])

  # The condition under which a champ is displayed, its own with every atom
  # guarded in turn by the champs it depends on. A champ met again while its
  # display condition is being computed (conditions that depend on each
  # other) is left out: such a form is broken in its own way, and the check
  # has to end.
  def display_condition(source)
    return @display_conditions[source.stable_id] if @display_conditions.key?(source.stable_id)

    @display_conditions[source.stable_id] = nil
    @display_conditions[source.stable_id] = guarded(source.condition, conditional_sources(source.condition))
  end

  def conditional_sources(condition)
    condition.sources.uniq.filter_map { |stable_id| @type_de_champs.find { it.stable_id == stable_id } }.filter(&:condition?)
  end

  # [[source, atoms]] for every variable whose domain the conjunction empties
  def unsatisfiable_variables(atoms)
    atoms
      .filter(&:constraining?)
      .group_by(&:left)
      .filter_map do |source, source_atoms|
        domain = source.domain(@type_de_champs)
        next if domain.nil?

        narrowed = source_atoms.reduce(domain) { |d, atom| d.restrict(atom.class, atom.right.value) }
        [source, source_atoms] if narrowed.empty?
      end
  end
end
