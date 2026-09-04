# frozen_string_literal: true

class Logic::ChampColumnValue < Logic::Term
  attr_reader :stable_id

  def initialize(stable_id, column_id)
    @stable_id, @column_id = stable_id, column_id
  end

  def sources = [stable_id]

  def compute(champs)
    targeted_champ = champs.find { |it| it.stable_id == stable_id }

    return nil if targeted_champ.nil?
    return nil if !targeted_champ.visible?
    return nil if !targeted_champ.condition_answered?

    column = targeted_column([targeted_champ.type_de_champ])

    # Without a cast the champ answers for itself, like Logic::ChampValue: the
    # column also feeds exports and the API, where "no answer" must stay blank.
    if !targeted_champ.is_type?(column.tdc_type)
      column.value(targeted_champ)
    elsif targeted_champ.drop_down_list? && targeted_champ.other?
      Champs::DropDownListChamp::OTHER
    elsif targeted_champ.checkbox?
      targeted_champ.condition_value
    else
      column.value(targeted_champ)
    end
  end

  def type(type_de_champs)
    column = targeted_column(type_de_champs)

    return :unmanaged if column.nil?

    type = column.type

    case type
    when :integer, :decimal
      Logic::ChampValue::CHAMP_VALUE_TYPE.fetch(:number)
    else
      type
    end
  end

  def options(type_de_champs, _operator_name = nil)
    return [] if targeted_column(type_de_champs).nil?

    targeted_column(type_de_champs).options_for_select
  end

  def errors(type_de_champs)
    # the targeted tdc is below current tdc or has been removed
    if targeted_column(type_de_champs).nil?
      [{ type: :not_available }]
    else
      []
    end
  end

  def to_h
    {
      "term" => self.class.name,
      "stable_id" => stable_id,
      "column_id" => @column_id,
    }
  end

  def self.from_h(h)
    self.new(h['stable_id'], h['column_id'])
  end

  def ==(other)
    self.class == other.class && to_h == other.to_h
  end

  def to_s(tdcs) = targeted_column(tdcs)&.label

  private

  def targeted_column(tdcs)
    targeted_tdc(tdcs)
      &.columns(procedure_id: nil) # dirty hack as we do not need procedure_id
      &.find { it.column_id == @column_id }
  end

  def targeted_tdc(tdcs) = tdcs.find { it.stable_id == stable_id }
end
