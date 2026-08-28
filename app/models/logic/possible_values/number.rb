# frozen_string_literal: true

# The values a numeric champ can still take: a finite union of disjoint
# intervals over the integers or the decimals, since they cannot be listed one
# by one. `min_inclusive` says whether the bound itself is allowed, which is
# what tells `> 18` from `>= 18`, and a `nil` bound stands for ±infinity.
# Restricting intersects, so the intervals only ever shrink; `n’est pas`
# (Logic::NotEq) is the one operator that cuts a hole in the middle, which is
# why several intervals are kept rather than one.
#
# A champ validated within limits (`positive_number`, `min_number`,
# `max_number`) starts out already narrowed to them, and remembers them in
# `limits` so that an error can say which limit a comparison runs into.
class Logic::PossibleValues::Number < Data.define(:integer, :intervals, :limits)
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

    # The interval as a champ of the given kind holds it.
    def snap(integer) = integer ? snap_to_integers : self
  end

  # The values the champ's own validation leaves it (see
  # NumberLimitValidator): non-negative when `positive_number`, within
  # `min_number`..`max_number` when `range_number`, both ends included and
  # either one optional. A bound is read the way the validator reads it, as
  # an integer or a decimal depending on the champ.
  def self.for(type_de_champ)
    integer = type_de_champ.integer_number?
    range = type_de_champ.range_number?
    range_min, range_max = [type_de_champ.min_number, type_de_champ.max_number].map do |bound|
      next if !range || bound.blank?

      integer ? bound.to_i : bound.to_f
    end
    min = [type_de_champ.positive_number? ? 0 : nil, range_min].compact.max
    limits = { min:, max: range_max } if min || range_max

    new(integer:, limits:).restrict(Logic::GreaterThanEq, min).restrict(Logic::LessThanEq, range_max)
  end

  def initialize(integer:, intervals: [Interval.unbounded], limits: nil)
    super(integer:, intervals: intervals.map { it.snap(integer) }.reject(&:empty?), limits:)
  end

  def empty? = intervals.empty?

  def union(other)
    return nil if !other.is_a?(self.class)

    with(intervals: coalesce(intervals + other.intervals))
  end

  def to_s(_type_de_champ = nil)
    return I18n.t('logic.possible_values.any') if intervals == [Interval.unbounded]

    intervals.map { describe(it) }.join(I18n.t('logic.possible_values.or'))
  end

  # The same champ as if it had no limits: what its comparisons alone leave.
  def unlimited = self.class.new(integer:)

  # Splits the values at every constant the comparisons mention: each constant on
  # its own and the open intervals between consecutive constants, so that an
  # comparison is either true or false on a whole region.
  def regions(comparisons)
    cuts = comparisons.map(&:last).filter { it.is_a?(Numeric) }.uniq.sort
    bounds = [nil, *cuts, nil]

    points = cuts.map { Interval.point(it) }
    gaps = bounds.each_cons(2).map { |low, high| Interval.new(min: low, min_inclusive: false, max: high, max_inclusive: false) }

    (points + gaps).map { intersect([it]) }.reject(&:empty?)
  end

  def max_regions(comparisons) = 2 * comparisons.map(&:last).uniq.size + 1

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
    with(intervals: intervals.product(others).map { |a, b| a.intersect(b) })
  end

  # Sorted intervals, overlapping or touching ones merged.
  def coalesce(intervals)
    intervals.map { it.snap(integer) }.reject(&:empty?).sort_by { [it.min ? 1 : 0, it.min || 0, it.min_inclusive ? 0 : 1] }.each_with_object([]) do |interval, merged|
      last = merged.last

      if last && touching?(last, interval)
        upper = [last, interval].find { it.max.nil? } || [last, interval].max_by { [it.max, it.max_inclusive ? 1 : 0] }
        merged[-1] = last.with(max: upper.max, max_inclusive: upper.max_inclusive)
      else
        merged << interval
      end
    end
  end

  # `a` starts before `b`: they touch when `a` reaches `b`'s start.
  def touching?(a, b)
    return true if a.max.nil? || b.min.nil?
    return true if a.max > b.min
    return true if a.max == b.min && (a.max_inclusive || b.min_inclusive)

    integer && a.max + 1 == b.min
  end

  def describe(interval)
    min, max = format(interval.min), format(interval.max)

    case [interval.min.nil?, interval.max.nil?]
    in [true, true] then I18n.t('logic.possible_values.any')
    in [true, false] then I18n.t(interval.max_inclusive ? 'logic.possible_values.number.at_most' : 'logic.possible_values.number.less_than', value: max)
    in [false, true] then I18n.t(interval.min_inclusive ? 'logic.possible_values.number.at_least' : 'logic.possible_values.number.more_than', value: min)
    in [false, false]
      if interval.min == interval.max
        min
      elsif interval.min_inclusive && interval.max_inclusive
        I18n.t('logic.possible_values.number.between', min:, max:)
      else
        I18n.t('logic.possible_values.number.between_exclusive', min:, max:)
      end
    end
  end

  def format(value)
    return nil if value.nil?

    value == value.to_i ? value.to_i.to_s : value.to_s
  end
end
