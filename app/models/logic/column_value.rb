# frozen_string_literal: true

class Logic::ColumnValue < Logic::Term
  def initialize(stable_id, column_id)
    @stable_id = stable_id
    @column_id = column_id
  end

  attr_reader :stable_id

  def sources = [stable_id].compact

  def compute(champs)
    targeted_champ = champs.find { |champ| champ.stable_id == stable_id }
    column = targeted_champ.type_de_champ.column(@column_id)

    return nil if column.nil?

    return nil if targeted_champ.nil?
    return nil if !targeted_champ.visible?
    return nil if targeted_champ.blank? && !targeted_champ.drop_down_other?

    # if it s a dropdown champ and a dropdown tdc (no cast)
    # and the dropdown is other, return other
    if targeted_champ.is_type?(column.tdc_type) && targeted_champ.drop_down_list? && targeted_champ.other?
      Champs::DropDownListChamp::OTHER
    else
      column.value(targeted_champ)
    end
  end

  def type(types_de_champ)
    column = targeted_column(types_de_champ)
    return :unmanaged if column.nil?

    type = column.type

    case type
    when :integer, :decimal
      Logic::ChampValue::CHAMP_VALUE_TYPE.fetch(:number)
    else
      type
    end
  end

  def options(types_de_champ, _operator_name = nil)
    column = targeted_column(types_de_champ)
    return [] if column.nil?

    column.options_for_select
  end

  def errors(types_de_champ)
    column = targeted_column(types_de_champ)
    return [{ type: :not_available }] if column.nil?

    # champ_column.present? but the tdc is below current tdc
    if !types_de_champ.map(&:stable_id).include?(stable_id)
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

  def to_s(types_de_champ) = targeted_column(types_de_champ)&.label

  private

  def targeted_tdc(tdcs) = tdcs.find { it.stable_id == stable_id }
  def targeted_column(tdcs) = targeted_tdc(tdcs)&.column(@column_id)
end
