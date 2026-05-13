# frozen_string_literal: true

class Logic::ColumnValue < Logic::Term
  delegate :label, :stable_id, to: :@champ_column

  def initialize(champ_column)
    @champ_column = champ_column
  end

  def sources = [stable_id]

  def compute(champs)
    targeted_champ = champs.find { |champ| champ.stable_id == stable_id }

    return nil if targeted_champ.nil?
    return nil if !targeted_champ.visible?
    return nil if targeted_champ.blank? && !targeted_champ.drop_down_other?

    @champ_column.value(targeted_champ)
  end

  def type(_type_de_champs)
    case @champ_column.type
    when :integer, :decimal
      Logic::ChampValue::CHAMP_VALUE_TYPE.fetch(:number)
    else
      @champ_column.type
    end
  end

  def options(_type_de_champs, _other = nil)
    @champ_column.options_for_select
  end

  def errors(type_de_champs)
    # champ_column.present? but the tdc is below current tdc
    if !type_de_champs.map(&:stable_id).include?(stable_id)
      [{ type: :not_available }]
    else
      []
    end
  end

  def to_h
    {
      "term" => self.class.name,
      "column_id" => @champ_column.h_id,
    }
  end

  def self.from_h(h)
    column = Column.find(h['column_id'].deep_symbolize_keys)
    self.new(column)
  end

  def ==(other)
    self.class == other.class && to_h == other.to_h
  end

  def to_s(_type_de_champ) = label
end
