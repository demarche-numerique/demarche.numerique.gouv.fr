# frozen_string_literal: true

class TypesDeChamp::DecimalNumber < TypeDeChamp
  def self.option_keys = [:positive_number, :min_number, :max_number, :range_number]
  def self.column_type = :decimal
  def self.conditionable? = true

  def prefillable? = true
  def customizable? = true
  def condition_value_type = :number
  store_accessor :options, :positive_number, :min_number, :max_number, :range_number
  boolean_options :positive_number, :range_number

  def typed_champ_value_for_export(champ, path = :value)
    champ_formatted_value(champ)
  end

  def typed_champ_value_for_api(champ, version: 2)
    case version
    when 1
      champ_formatted_value(champ)
    else
      super
    end
  end

  def champ_default_export_value(path = :value)
    0
  end

  private

  def champ_formatted_value(champ)
    champ.value&.to_f
  end
end
