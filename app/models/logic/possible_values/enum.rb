# frozen_string_literal: true

# The set of options a single-choice champ (drop down, pays, region, yes/no,
# checkbox…) can still hold. `est` keeps only the option asked for, `n’est
# pas` drops it, so two different `est` on the same champ leave nothing.
class Logic::PossibleValues::Enum < Data.define(:values)
  def initialize(values:) = super(values: values.to_set)

  def empty? = values.empty?

  def limits = nil

  def union(other) = other.is_a?(self.class) ? self.class.new(values | other.values) : nil

  # In the order the champ lists its options
  def sort_key = [0]

  # The labels of the options, in the order the champ lists them.
  def to_s(type_de_champ)
    labels = type_de_champ.condition_options.to_h { |label, value| [value, label] }

    ordered = (labels.keys & values.to_a) + (values.to_a - labels.keys)

    ordered.map { labels.fetch(it) { label_for(it) } }.join(', ')
  end

  # Every option the comparisons mention on its own, and all the others together.
  def regions(comparisons)
    mentioned = comparisons.map(&:last).uniq

    singletons = mentioned.map { self.class.new(values & [it]) }
    rest = self.class.new(values - mentioned)

    [*singletons, rest].reject(&:empty?)
  end

  def max_regions(comparisons) = [comparisons.map(&:last).uniq.size + 1, values.size].min

  def restrict(operator_class, value)
    case operator_class.name
    when Logic::Eq.name then self.class.new(values & [value])
    when Logic::NotEq.name then self.class.new(values - [value])
    else self
    end
  end

  private

  def label_for(value)
    case value
    when true then I18n.t('utils.yes')
    when false then I18n.t('utils.no')
    when Champs::DropDownListChamp::OTHER then I18n.t('logic.possible_values.other')
    else value.to_s
    end
  end
end
