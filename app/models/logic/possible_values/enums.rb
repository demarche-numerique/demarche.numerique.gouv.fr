# frozen_string_literal: true

# A multiple-choice champ holds a subset of its options, so listing the values
# it can take would mean listing every subset — 2^n of them for n options. The
# comparisons only ever require an option to be selected or not, so it keeps
# just the pair of those requirements, contradictory as soon as one option is
# in both, or as soon as every option is excluded: a filled champ has at least
# one selected.
class Logic::PossibleValues::Enums < Data.define(:options, :must_include, :must_exclude)
  def initialize(options:, must_include: Set.new, must_exclude: Set.new) = super(options: options.to_set, must_include:, must_exclude:)

  def empty? = must_include.intersect?(must_exclude) || (options.any? && options.subset?(must_exclude))

  def limits = nil

  # Two requirements sets can only be told as one when they differ on a single
  # option, which then stops being required either way.
  def union(other)
    return nil if !other.is_a?(self.class)

    swapped = (must_include & other.must_exclude) | (must_exclude & other.must_include)
    same = (must_include - swapped) == (other.must_include - swapped) && (must_exclude - swapped) == (other.must_exclude - swapped)

    return nil if swapped.size != 1 || !same

    with(must_include: must_include - swapped, must_exclude: must_exclude - swapped)
  end

  def to_s(type_de_champ)
    labels = type_de_champ.condition_options.to_h { |label, value| [value, label] }
    with = must_include.map { labels.fetch(it, it.to_s) }
    without = must_exclude.map { labels.fetch(it, it.to_s) }

    [
      with.presence && I18n.t('logic.possible_values.enums.with', options: with.join(', ')),
      without.presence && I18n.t('logic.possible_values.enums.without', options: without.join(', ')),
    ].compact.join(', ').presence || I18n.t('logic.possible_values.enums.any')
  end

  # Every combination of the options the comparisons mention being selected or not.
  def regions(comparisons)
    mentioned = comparisons.map(&:last).uniq

    (0..mentioned.size).flat_map { |n| mentioned.combination(n).to_a }.map do |selected|
      with(must_include: must_include | selected, must_exclude: must_exclude | (mentioned - selected))
    end.reject(&:empty?)
  end

  # Exponential in the mentioned options: check it before calling `regions`.
  def max_regions(comparisons) = 2**comparisons.map(&:last).uniq.size

  def restrict(operator_class, value)
    case operator_class.name
    when Logic::IncludeOperator.name then with(must_include: must_include | [value], must_exclude: must_exclude)
    when Logic::ExcludeOperator.name then with(must_include: must_include, must_exclude: must_exclude | [value])
    else self
    end
  end
end
