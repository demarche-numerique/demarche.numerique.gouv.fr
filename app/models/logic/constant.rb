# frozen_string_literal: true

class Logic::Constant < Logic::Term
  attr_reader :value

  def initialize(value)
    @value = value
  end

  def sources
    []
  end

  def compute(_champs = nil) = @value

  def to_s(_type_de_champs = [])
    case @value
    when TrueClass
      I18n.t('utils.yes')
    when FalseClass
      I18n.t('utils.no')
    when Champs::DropDownListChamp::OTHER
      'Autre'
    else
      @value.to_s
    end
  end

  def type(_type_de_champs = [])
    case @value
    when TrueClass, FalseClass
      :boolean
    when Integer, Float
      :number
    else
      @value.class.name.downcase.to_sym
    end
  end

  def errors(_type_de_champs = nil) = []

  def to_h
    {
      "term" => self.class.name,
      "value" => @value,
    }
  end

  def self.from_h(h)
    self.new(h['value'])
  end

  def to_expr = @value

  def ==(other)
    self.class == other.class && @value == other.value
  end
end
