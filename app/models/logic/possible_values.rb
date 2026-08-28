# frozen_string_literal: true

# What a champ can still hold once the comparisons of a condition have been
# applied to it: `age` starts out unbounded, `age >= 18` leaves [18, +inf[,
# and a further `age < 10` leaves nothing — nothing left is how a
# contradiction shows up. It starts full (`PossibleValues.for(type_de_champ)`,
# `PossibleValues.for_column(column)`), narrows through
# `#restrict(operator_class, value)` and can be asked whether it is `#empty?`.
#
# Restricting only ever removes values, never adds any, so the comparisons can
# be folded in in any order and the fold stopped as soon as nothing is left.
#
# The four implementations hold their values however suits them — a set of
# options, a pair of requirements, intervals, departement codes — and
# Logic::Solver only ever calls `restrict` and `empty?`, so a new kind of
# champ is a new class plus a line in `.for`. This is the part an SMT solver
# calls a *theory solver*: the boolean search asks "can these comparisons hold
# together?" and the champ they constrain answers. The set itself is a
# *domain*, in the sense constraint solvers give the word.
#
# This models the value of a *filled* champ. A blank or hidden champ makes
# every comparison false (see Logic::BinaryOperator#compute), which is handled
# by Logic::Solver, not here.
module Logic::PossibleValues
  def self.for(type_de_champ)
    case type_de_champ.condition_value_type
    when :number
      Number.new(integer: type_de_champ.type_champ == TypeDeChamp.type_champs.fetch(:integer_number))
    when :departement_enum, :commune_enum, :epci_enum, :address
      Geo.new
    else
      choices(type_de_champ.condition_value_type, type_de_champ.condition_options)
    end
  end

  def self.for_column(column)
    case column.type
    when :integer
      Number.new(integer: true)
    when :decimal
      Number.new(integer: false)
    else
      choices(column.type, column.options_for_select)
    end
  end

  # Picked among options: yes/no, one of them, several of them.
  def self.choices(type, options)
    case type
    when :boolean
      Enum.new([true, false])
    when :enum
      Enum.new(options.map(&:second))
    when :enums
      Enums.new(options.map(&:second))
    end
  end
  private_class_method :choices
end
