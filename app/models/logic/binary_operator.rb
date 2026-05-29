# frozen_string_literal: true

class Logic::BinaryOperator < Logic::Term
  attr_reader :left, :right

  def initialize(left, right)
    @left, @right = left, right
  end

  def sources
    [@left, @right].flat_map(&:sources)
  end

  def terms = [self] + @left.terms + @right.terms

  def to_h
    {
      "term" => self.class.name,
      "left" => @left.to_h,
      "right" => @right.to_h,
    }
  end

  def self.from_h(h)
    self.new(Logic.from_h(h['left']), Logic.from_h(h['right']))
  end

  def errors(type_de_champs = [])
    errors = []

    if @left.type(type_de_champs) != :number || @right.type(type_de_champs) != :number
      errors << { type: :required_number, operator_name: self.class.name }
    end

    errors + @left.errors(type_de_champs) + @right.errors(type_de_champs)
  end

  def type(type_de_champs = []) = :boolean

  def compute(champs = [])
    l = @left.compute(champs)
    r = @right.compute(champs)

    l = l[:value] if l.is_a?(Hash)

    l&.send(operation, r) || false
  end

  def to_s(type_de_champs) = "(#{@left.to_s(type_de_champs)} #{operation} #{@right.to_s(type_de_champs)})"

  def ==(other)
    self.class == other.class &&
      @left == other.left &&
      @right == other.right
  end
end
