# frozen_string_literal: true

# A domain is the set of values a champ can still take once the atoms of a
# condition have been applied to it. Every domain starts full
# (`Domain.for(type_de_champ)`, `Domain.for_column(column)`), narrows through
# `#restrict(operator_class, value)` and can be asked whether it is `#empty?` —
# an empty domain means the atoms restricting it are contradictory.
#
# Domains model the value of a *filled* champ. A blank or hidden champ makes
# every atom false (see Logic::BinaryOperator#compute), which is handled by the
# satisfiability check, not here.
module Logic::Domain
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

  # The domains picked among options: yes/no, one of them, several of them.
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
