# frozen_string_literal: true

class Champs::PhoneChamp < Champs::TextChamp
  validates :value,
    phone: {
      possible: true,
      allow_blank: true,
      message: I18n.t(:not_a_phone, scope: 'activerecord.errors.messages'),
    },
    if: -> { validate_champ_value? && !Phonelib.valid_for_countries?(value, TypesDeChamp::PhoneTypeDeChamp::DEFAULT_COUNTRY_CODES) }
end
