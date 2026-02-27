# frozen_string_literal: true

class Champs::FormattedChamp < Champ
  validates_with FormattedChampValidator, if: :validate_champ_value?
end
