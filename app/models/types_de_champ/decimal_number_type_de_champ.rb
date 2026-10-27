# frozen_string_literal: true

class TypesDeChamp::DecimalNumberTypeDeChamp < TypesDeChamp::NumericTypeDeChamp
  def self.column_type = :decimal

  private

  def champ_formatted_value(champ)
    champ.value&.to_f
  end
end
