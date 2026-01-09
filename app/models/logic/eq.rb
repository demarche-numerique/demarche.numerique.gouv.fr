# frozen_string_literal: true

class Logic::Eq < Logic::BinaryOperator
  def operation = :==

  def errors(type_de_champs = [])
    errors = [@left, @right]
      .filter { |term| term.type(type_de_champs) == :unmanaged }
      .map { |term| { type: :unmanaged, stable_id: term.stable_id } }

    left_type = @left.type(type_de_champs)

    if left_type == :enum && @left.options(type_de_champs, self.class.name).blank?
      errors << {
        type: :empty_options,
        stable_id: @left.stable_id,
        right: @right,
      }
    elsif !Logic.compatible_type?(@left, @right, type_de_champs)
      errors << {
        type: :incompatible,
        stable_id: @left.try(:stable_id),
        right: @right,
        operator_name: self.class.name,
      }
    elsif left_type == :enum && !@left.options(type_de_champs, self.class.name).map(&:second).include?(right.value)
      errors << {
        type: :not_included,
        stable_id: @left.stable_id,
        right: @right,
      }
    elsif left_type == :enums
      errors << {
        type: :required_include,
        stable_id: @left.try(:stable_id),
        operator_name: self.class.name,
      }
    end

    errors + @left.errors(type_de_champs) + @right.errors(type_de_champs)
  end

  def ==(other)
    self.class == other.class &&
      [@left, @right].permutation.any? { |p| p == [other.left, other.right] }
  end

  def hash
    term = self.class.name
    sorted_operands = operands.sort_by(&:hash)
    [term, *sorted_operands].hash
  end
end
