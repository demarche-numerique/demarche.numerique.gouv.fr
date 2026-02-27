# frozen_string_literal: true

class Champs::BooleanChamp < Champ
  TRUE_VALUE = 'true'
  FALSE_VALUE = 'false'

  before_validation :set_value_to_nil, if: -> { value.blank? }
  before_validation :set_value_to_false, unless: -> { ([nil, TRUE_VALUE, FALSE_VALUE]).include?(value) }

  validates :value, inclusion: [TRUE_VALUE, FALSE_VALUE], allow_nil: true, allow_blank: false, if: :validate_champ_value?

  def true?
    value == TRUE_VALUE
  end

  def search_terms
    if true?
      [libelle]
    end
  end

  private

  def set_value_to_nil
    self.value = nil
  end

  def set_value_to_false
    self.value = FALSE_VALUE
  end
end
