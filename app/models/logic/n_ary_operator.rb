# frozen_string_literal: true

class Logic::NAryOperator < Logic::Term
  attr_reader :operands

  def initialize(operands)
    @operands = operands
  end

  def sources
    @operands.flat_map(&:sources)
  end

  def to_h
    {
      "term" => self.class.name,
      "operands" => @operands.map(&:to_h),
    }
  end

  def self.from_h(h)
    self.new(h['operands'].map { |operand_h| Logic.from_h(operand_h) })
  end

  def errors(type_de_champs = [])
    errors = []

    if @operands.empty?
      errors += ["opérateur '#{operator_name}' vide"]
    end

    not_booleans = @operands.filter { |operand| operand.type(type_de_champs) != :boolean }
    if not_booleans.present?
      errors += ["'#{operator_name}' ne contient pas que des booléens : #{not_booleans.map { |o| o.to_s(type_de_champs) }.join(', ')}"]
    end

    errors + @operands.flat_map { |operand| operand.errors(type_de_champs) }
  end

  def type(_type_de_champs = []) = :boolean

  def ==(other)
    self.class == other.class &&
      @operands.count == other.operands.count &&
      @operands.all? do |operand|
        @operands.count { |o| o == operand } == other.operands.count { |o| o == operand }
      end
  end

  def hash
    term = self.class.name
    sorted_operands = operands.sort_by(&:hash)
    [term, *sorted_operands].hash
  end
end
