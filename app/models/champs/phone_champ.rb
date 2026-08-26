# frozen_string_literal: true

class Champs::PhoneChamp < Champs::TextChamp
  validates :value,
    phone: {
      possible: true,
      allow_blank: true,
      message: I18n.t(:not_a_phone, scope: 'activerecord.errors.messages'),
    },
    if: -> { should_validate_in_current_context? && !Phonelib.valid_for_countries?(value, TypesDeChamp::Phone::DEFAULT_COUNTRY_CODES) }
end
