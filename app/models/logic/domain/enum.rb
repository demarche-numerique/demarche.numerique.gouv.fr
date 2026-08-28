# frozen_string_literal: true

# The set of options a single-choice champ (drop down, pays, region, yes/no,
# checkbox…) can still hold.
class Logic::Domain::Enum < Data.define(:values)
  def initialize(values:) = super(values: values.to_set)

  def empty? = values.empty?

  def restrict(operator_class, value)
    case operator_class.name
    when Logic::Eq.name then self.class.new(values & [value])
    when Logic::NotEq.name then self.class.new(values - [value])
    else self
    end
  end
end
