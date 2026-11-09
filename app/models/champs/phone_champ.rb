# frozen_string_literal: true

class Champs::PhoneChamp < Champs::TextChamp
  validates :value,
    phone: {
      possible: true,
      allow_blank: true,
      message: :not_a_phone,
    },
    if: -> { should_validate_in_current_context? && !Phonelib.valid_for_countries?(value, TypesDeChamp::PhoneTypeDeChamp::DEFAULT_COUNTRY_CODES) }
end
