# frozen_string_literal: true

class TypesDeChamp::IbanTypeDeChamp < TypesDeChamp::TypeDeChampBase
  def estimated_fill_duration
    FILL_DURATION_MEDIUM
  end

  def filled_champ_value_for_api(champ, version: 2)
    filled_champ_value(champ).gsub(/\s+/, '')
  end
end
