# frozen_string_literal: true

class Champs::FormattedChamp < Champ
  validates_with FormattedChampValidator, if: :should_validate_in_current_context?
end
