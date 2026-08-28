# frozen_string_literal: true

# The set of options a single-choice champ (drop down, pays, region, yes/no,
# checkbox…) can still hold. `est` keeps only the option asked for, `n’est
# pas` drops it, so two different `est` on the same champ leave nothing.
class Logic::PossibleValues::Enum < Data.define(:values)
  def initialize(values:) = super(values: values.to_set)

  def empty? = values.empty?

  def limits = nil

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
end
