# frozen_string_literal: true

class TypesDeChamp::PrefillBoolean < TypesDeChamp::Prefill
  TRUE_VALUES = [true, 1, "1", "t", "T", "true", "TRUE", "on", "ON"].to_set
  FALSE_VALUES = ActiveModel::Type::Boolean::FALSE_VALUES

  private

  def screened_value(champ, value)
    if TRUE_VALUES.include?(value)
      'true'
    elsif FALSE_VALUES.include?(value)
      'false'
    end
  end
end
