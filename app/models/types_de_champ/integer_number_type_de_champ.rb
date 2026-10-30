# frozen_string_literal: true

class TypesDeChamp::IntegerNumberTypeDeChamp < TypesDeChamp::NumericTypeDeChamp
  def self.column_type = :integer

  private

  def champ_formatted_value(champ)
    champ.value&.to_i
  end
end
