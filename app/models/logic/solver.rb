# frozen_string_literal: true

# Checks that a condition can be true for at least one way of filling the
# form: `a == 2 and a == 3` or `a > 3 and a < 2` never are, nor is
# `b == 'x' and a < 5` when `b` is only displayed if `a > 10`. A condition
# that can never be true hides its champ for ever, which is a defect of the
# form.
#
# ## What is checked
#
# A condition is read as a list of alternatives — the operands of an `or`
# (Logic::Or) — each one a list of comparisons that must hold together, an
# `and` (Logic::And):
#
#   (age >= 18 and dept == 75) or (age >= 18 and tuteur == 'oui')
#    \_______ alternative 1 __/     \_______ alternative 2 ______/
#
# The condition is possible as soon as one alternative is, and an alternative
# is possible when no champ is asked for two incompatible things at once: its
# comparisons are grouped by champ and folded into the values that champ can
# still take (Logic::PossibleValues). A champ left with no value at all is a
# contradiction.
#
# ## How the alternatives are searched
#
# They are never listed up front: n two-way `or` give up to 2^n of them. They
# are walked instead, in three moves:
#
#   guess       open one `or` and try one of its branches;
#   check       after every guess, look at the comparisons accepted so far and
#               stop at once if two of them already contradict each other —
#               this is what kills whole families of alternatives without ever
#               building them;
#   backtrack   a dead branch is abandoned and the next one tried; when every
#               branch of every `or` dies, the condition is impossible.
#
# ## Where this comes from
#
# This is a small SAT solver, and the literature has its own names for all of
# the above, should you want to look it up: a comparison is an *atom* or a
# *literal*, an `and` and an `or` are a *conjunction* and a *disjunction*,
# the shape a condition is read in is *disjunctive normal form*, "possible"
# is *satisfiable*, a conflict is an *unsat core*, and the three moves are
# the backbone of the DPLL algorithm (Davis–Putnam–Logemann–Loveland, 1962),
# which works on clauses and adds unit propagation on top of them.
# Real SAT solvers add clause learning — remembering why a branch failed, so
# as not to retry it elsewhere — and cleverer heuristics; neither is needed
# for conditions holding tens of comparisons rather than millions.
#
# Plain DPLL only knows booleans that are true or false on their own, while
# `age >= 18` and `age < 10` are two comparisons whose incompatibility is
# invisible to it. Deciding whether a group of comparisons means anything is
# therefore delegated to Logic::PossibleValues, one implementation per kind of
# champ — the split SMT solvers call DPLL(T).
#
# A blank or hidden champ makes every comparison on it false, so a comparison
# on a conditional champ is only ever true when the champ is displayed: the
# condition is also checked rewritten with the display condition of each
# champ it targets (Logic::DisplayConditions).
class Logic::Solver
  def initialize(type_de_champs)
    @type_de_champs = type_de_champs
    @display_conditions = Logic::DisplayConditions.new(type_de_champs)
  end

  def errors(condition)
    contradictions(condition).presence || unreachable(condition)
  end

  private

  def contradictions(condition)
    conflicts([condition]).map { |source, comparisons, limits| { type: :contradiction, stable_id: source.stable_id, comparisons:, limits: }.compact }.uniq
  end

  # The search itself: the champs left without a value on every way of
  # reading `terms` together with the `comparisons` already accepted — none
  # when one way holds, and a failed search has to say why.
  #
  # `and` are flattened into terms and `or` opened one at a time, each
  # branch pushed back into terms, so nesting of any depth is handled
  # without ever building the alternatives. The `or` opened first is one
  # on a champ the comparisons already constrain, so that a dead alternative
  # shows up before the branches multiply.
  def conflicts(terms, comparisons = [])
    ors, more = flatten(terms).partition { it.is_a?(Logic::Or) }
    comparisons += more

    found = conflicting_sources(comparisons)
    return found if found.any? || ors.empty?

    constrained = comparisons.flat_map(&:sources)
    branching = ors.delete_at(ors.index { it.sources.intersect?(constrained) } || 0)

    branching.operands.each_with_object([]) do |branch, all|
      found = conflicts([branch, *ors], comparisons)
      return [] if found.empty?

      all.concat(found)
    end
  end

  # The operands of every nested `and`, brought up to one level
  def flatten(terms) = terms.flat_map { it.is_a?(Logic::And) ? flatten(it.operands) : [it] }

  # The champs the condition targets may only be displayed under conditions of
  # their own: the condition is dead when no comparison on them can hold
  # together with them. The culprits are the targeted champs whose display
  # condition alone kills it, or all of them when only their combination does.
  def unreachable(condition)
    sources = @display_conditions.conditional_sources(condition)

    return [] if sources.empty?
    return [] if contradictions(@display_conditions.apply(condition, sources)).empty?

    culprits = sources.filter { contradictions(@display_conditions.apply(condition, [it])).any? }.presence || sources

    culprits.map { { type: :unreachable, stable_id: it.stable_id } }
  end

  # Every comparison constrains exactly one champ, so the champs are
  # independent and can be looked at one at a time: take everything that champ
  # could hold, narrow it with each comparison on it, and if nothing is left
  # those comparisons cannot hold together. They are returned along with the
  # champ, to be named in the error, and with the champ's validation limits
  # when the comparisons only conflict within them: `age > 6` on a champ
  # capped at 5 is fine on its own, and the error has to say what it runs into.
  #
  # [[source, comparisons, limits]] for every champ the alternative leaves
  # with no possible value
  def conflicting_sources(comparisons)
    comparisons
      .filter { checkable?(it) }
      .group_by(&:left)
      .filter_map do |source, source_comparisons|
        values = source.possible_values(@type_de_champs)
        next if values.nil?

        next if !restrict(values, source_comparisons).empty?

        [source, source_comparisons, limits_to_blame(values, source_comparisons)]
      end
  end

  def limits_to_blame(values, comparisons)
    values.limits if values.limits && !restrict(values.unlimited, comparisons).empty?
  end

  def restrict(values, comparisons) = comparisons.reduce(values) { |v, comparison| v.restrict(comparison.class, comparison.right.value) }

  # A comparison Logic::PossibleValues can interpret: `champ operator
  # constant`. Anything else is left out, which can only make a condition look
  # more possible than it is — the check then misses contradictions rather
  # than inventing them, and never blocks a publication by mistake.
  def checkable?(comparison)
    comparison.is_a?(Logic::BinaryOperator) &&
      !comparison.is_a?(Logic::EmptyOperator) &&
      comparison.left.respond_to?(:possible_values) &&
      comparison.right.is_a?(Logic::Constant)
  end
end
