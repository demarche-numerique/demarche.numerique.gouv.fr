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

  def union(other)
    return nil if !other.is_a?(self.class)

    self.class.new(integer: integer, intervals: coalesce(intervals + other.intervals))
  end

  # Ascending: a bound before what lies past it
  def sort_key
    interval = intervals.first

    [0, interval.min || -Float::INFINITY, interval.min_inclusive ? 0 : 1]
  end

  def to_s(_type_de_champ = nil)
    return I18n.t('logic.domain.any') if intervals == [Interval.unbounded]

    intervals.map { describe(it) }.join(I18n.t('logic.domain.or'))
  end

  # Splits the domain at every constant the atoms mention: each constant on
  # its own and the open intervals between consecutive constants, so that an
  # atom is either true or false on a whole region.
  def regions(atoms)
    cuts = atoms.map(&:last).filter { it.is_a?(Numeric) }.uniq.sort
    bounds = [nil, *cuts, nil]

    points = cuts.map { Interval.point(it) }
    gaps = bounds.each_cons(2).map { |low, high| Interval.new(min: low, min_inclusive: false, max: high, max_inclusive: false) }

    (points + gaps).map { intersect([it]) }.reject(&:empty?)
  end

  def max_regions(atoms) = 2 * atoms.map(&:last).uniq.size + 1

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

  # Sorted intervals, overlapping or touching ones merged.
  def coalesce(intervals)
    intervals.map { normalize(it) }.reject(&:empty?).sort_by { [it.min ? 1 : 0, it.min || 0, it.min_inclusive ? 0 : 1] }.each_with_object([]) do |interval, merged|
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
    in [true, true] then I18n.t('logic.domain.any')
    in [true, false] then I18n.t(interval.max_inclusive ? 'logic.domain.number.at_most' : 'logic.domain.number.less_than', value: max)
    in [false, true] then I18n.t(interval.min_inclusive ? 'logic.domain.number.at_least' : 'logic.domain.number.more_than', value: min)
    in [false, false]
      if interval.min == interval.max
        min
      elsif interval.min_inclusive && interval.max_inclusive
        I18n.t('logic.domain.number.between', min:, max:)
      else
        I18n.t('logic.domain.number.between_exclusive', min:, max:)
      end
    end
  end

  def format(value)
    return nil if value.nil?

    value == value.to_i ? value.to_i.to_s : value.to_s
  end
end
