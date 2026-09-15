# frozen_string_literal: true

class Logic::Empty < Logic::Term
  def sources
    []
  end

  def to_s(_type_de_champs = []) = I18n.t('logic.empty')

  def type(_type_de_champs = []) = :empty

  def errors(_type_de_champs = []) = ['empty']

  def to_h
    {
      "term" => self.class.name,
    }
  end

  def self.from_h(_h)
    self.new
  end

  def to_expr = nil

  def ==(other)
    self.class == other.class
  end

  def value
    nil
  end
end
