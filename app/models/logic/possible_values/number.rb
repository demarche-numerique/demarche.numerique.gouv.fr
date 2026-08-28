# frozen_string_literal: true

# The values a numeric champ can still take: a finite union of disjoint
# intervals over the integers or the decimals, since they cannot be listed one
# by one. `min_inclusive` says whether the bound itself is allowed, which is
# what tells `> 18` from `>= 18`, and a `nil` bound stands for ±infinity.
# Restricting intersects, so the intervals only ever shrink; `n’est pas`
# (Logic::NotEq) is the one operator that cuts a hole in the middle, which is
# why several intervals are kept rather than one.
class Logic::PossibleValues::Number < Data.define(:integer, :intervals)
  Interval = Data.define(:min, :min_inclusive, :max, :max_inclusive) do
    def self.unbounded = new(min: nil, min_inclusive: false, max: nil, max_inclusive: false)

    def self.at_least(value, inclusive:) = new(min: value, min_inclusive: inclusive, max: nil, max_inclusive: false)

    def self.at_most(value, inclusive:) = new(min: nil, min_inclusive: false, max: value, max_inclusive: inclusive)

    def self.point(value) = new(min: value, min_inclusive: true, max: value, max_inclusive: true)

    # The tightest interval contained in both: the higher of the two lower
    # bounds, the lower of the two upper ones. A missing bound is no
    # constraint, so it never wins.
    def intersect(other)
      lower = [self, other].reject { it.min.nil? }.max_by { [it.min, it.min_inclusive ? 0 : 1] }
      upper = [self, other].reject { it.max.nil? }.min_by { [it.max, it.max_inclusive ? 1 : 0] }

      with(
        min: lower&.min,
        min_inclusive: lower.nil? ? false : lower.min_inclusive,
        max: upper&.max,
        max_inclusive: upper.nil? ? false : upper.max_inclusive
      )
    end

    # On integers an open bound is the same as a closed bound one step
    # further in, which lets `> 2 and < 3` collapse to nothing.
    def snap_to_integers
      with(
        min: min.nil? ? nil : (min_inclusive ? min.ceil : min.floor + 1),
        min_inclusive: !min.nil?,
        max: max.nil? ? nil : (max_inclusive ? max.floor : max.ceil - 1),
        max_inclusive: !max.nil?
      )
    end

    def empty?
      return false if min.nil? || max.nil?
      return true if min > max

      min == max && !(min_inclusive && max_inclusive)
    end
  end

  def initialize(integer:, intervals: [Interval.unbounded])
    super(integer:, intervals: intervals.map { integer ? it.snap_to_integers : it }.reject(&:empty?))
  end

  def empty? = intervals.empty?

  def restrict(operator_class, value)
    return self if !value.is_a?(Numeric)

    intersect(
      case operator_class.name
      when Logic::Eq.name then [Interval.point(value)]
      when Logic::NotEq.name then [Interval.at_most(value, inclusive: false), Interval.at_least(value, inclusive: false)]
      when Logic::LessThan.name then [Interval.at_most(value, inclusive: false)]
      when Logic::LessThanEq.name then [Interval.at_most(value, inclusive: true)]
      when Logic::GreaterThan.name then [Interval.at_least(value, inclusive: false)]
      when Logic::GreaterThanEq.name then [Interval.at_least(value, inclusive: true)]
      else return self
      end
    )
  end

  private

  # Every kept interval crossed with every new one: intersecting two unions of
  # intervals means intersecting them pairwise, and the constructor drops the
  # pairs that do not overlap.
  def intersect(others)
    self.class.new(integer: integer, intervals: intervals.product(others).map { |a, b| a.intersect(b) })
  end
end
