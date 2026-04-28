# frozen_string_literal: true

class Logic::ColumnValue < Logic::Term
  def initialize(champ_column, h_id: nil)
    @champ_column = champ_column
    @column_h_id = h_id
  end

  def sources = [stable_id].compact

  def compute(champs)
    return nil if @champ_column.nil?

    targeted_champ = champs.find { |champ| champ.stable_id == stable_id }

    return nil if targeted_champ.nil?
    return nil if !targeted_champ.visible?
    return nil if targeted_champ.blank? && !targeted_champ.drop_down_other?

    @champ_column.value(targeted_champ)
  end

  def type(_type_de_champs)
    return :unmanaged if @champ_column.nil?

    case @champ_column.type
    when :integer, :decimal
      Logic::ChampValue::CHAMP_VALUE_TYPE.fetch(:number)
    else
      @champ_column.type
    end
  end

  def options(_type_de_champs, _other = nil)
    return [] if @champ_column.nil?

    @champ_column.options_for_select
  end

  def label = @champ_column&.label
  def stable_id = @champ_column&.stable_id

  def errors(type_de_champs)
    return [{ type: :not_available }] if @champ_column.nil?

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
      "column_id" => @champ_column&.h_id || @column_h_id,
    }
  end

  def self.from_h(h)
    h_id = h['column_id'].deep_symbolize_keys
    column = Column.find(h_id)
    self.new(column)
  rescue ActiveRecord::RecordNotFound
    # the underlying column has been destroyed; keep the reference so the
    # condition can self-heal if the column reappears, and so errors() can
    # signal :not_available to the editor
    self.new(nil, h_id: h_id)
  end

  def ==(other)
    self.class == other.class && to_h == other.to_h
  end

  def to_s(_type_de_champ) = label
end
