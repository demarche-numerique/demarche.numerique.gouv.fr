# frozen_string_literal: true

# A blank or hidden champ makes every comparison on it false (see
# Logic::BinaryOperator#compute), so a comparison on a conditional champ is
# only ever true when that champ is displayed. This rewrites a condition to
# say so: every comparison on one of the given champs is joined with the
# condition under which the champ is displayed — its own, rewritten the same
# way for the champs it depends on, and so on.
#
#   b == 'x' and a < 5           with b displayed when a > 10
#   (b == 'x' and a > 10) and a < 5
#
# Logic::Solver checks the rewritten condition to tell a condition that can
# never be true because of the form around it from one contradicting itself.
class Logic::DisplayConditions
  def initialize(type_de_champs)
    @type_de_champs = type_de_champs
    @conditions = {}
  end

  # The champs the condition targets that are displayed under a condition of
  # their own
  def conditional_sources(condition)
    condition.sources.uniq.filter_map { |stable_id| @type_de_champs.find { it.stable_id == stable_id } }.filter(&:condition?)
  end

  # The condition with every comparison on one of the sources holding only
  # while that champ is displayed. Adding the display condition to the
  # comparisons rather than to the whole condition keeps an `or` alive
  # through the branches that do not need the champ.
  def apply(condition, sources)
    and_with(*hoist_shared(condition, sources))
  end

  private

  # [term, conditions]: the term with the display conditions added to its
  # comparisons, except for the ones every operand shares, returned to be
  # added once above. Lifting them out is `(a and g) or (b and g)` rewritten
  # as `(a or b) and g`, and it is what keeps a chain of display conditions
  # flat instead of copied into every branch.
  #
  # This lifting is what stands in for clause learning in Logic::Solver: a
  # chain of champs each displayed under an `or` on the previous one folds
  # into one flat `and` of `or`s, which the search prunes from the top. It
  # stops at an `or` whose branches target different champs — the display
  # condition is then copied into the branches that need it, and a dead
  # condition on such a chain is searched once per branch at every level.
  def hoist_shared(term, sources)
    case term
    when Logic::And, Logic::Or
      parts = term.operands.map { hoist_shared(it, sources) }
      shared = parts.map(&:last).reduce(:&) || []

      [term.class.new(parts.map { |operand, conditions| and_with(operand, conditions - shared) }), shared]
    else
      [term, sources.filter { term.sources.include?(it.stable_id) }.filter_map { of(it) }]
    end
  end

  def and_with(term, conditions) = conditions.empty? ? term : Logic::And.new([term, *conditions])

  # The condition under which a champ is displayed, its own with every
  # comparison held in turn by the champs it depends on. A champ met again
  # while its display condition is being computed (conditions that depend on
  # each other) is left out: such a form is broken in its own way, and the
  # rewrite has to end.
  def of(source)
    return @conditions[source.stable_id] if @conditions.key?(source.stable_id)

    @conditions[source.stable_id] = nil
    @conditions[source.stable_id] = apply(source.condition, conditional_sources(source.condition))
  end
end
