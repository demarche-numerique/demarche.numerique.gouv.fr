# frozen_string_literal: true

# A finite union of disjoint intervals over the integers or the decimals.
# `nil` bounds stand for ±infinity.
class Logic::Domain::Number < Data.define(:integer, :intervals)
  Interval = Data.define(:min, :min_inclusive, :max, :max_inclusive) do
    def self.unbounded = new(min: nil, min_inclusive: false, max: nil, max_inclusive: false)

    def self.at_least(value, inclusive:) = new(min: value, min_inclusive: inclusive, max: nil, max_inclusive: false)

    def self.at_most(value, inclusive:) = new(min: nil, min_inclusive: false, max: value, max_inclusive: inclusive)

    def self.point(value) = new(min: value, min_inclusive: true, max: value, max_inclusive: true)

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
    def integer
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
    super(integer:, intervals: intervals.map { integer ? it.integer : it }.reject(&:empty?))
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

  def intersect(others)
    self.class.new(integer: integer, intervals: intervals.product(others).map { |a, b| a.intersect(b) })
  end

  def normalize(interval) = integer ? interval.integer : interval
end
