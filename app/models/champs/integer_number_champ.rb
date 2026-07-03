# frozen_string_literal: true

class Champs::IntegerNumberChamp < Champ
  validates_with NumberLimitValidator, if: :should_validate_in_current_context?
  before_validation :format_value

  validates :value, numericality: {
    only_integer: true,
    allow_nil: true,
    allow_blank: true,
    message: -> (object, _data) {
      # i18n-tasks-use t('errors.messages.not_an_integer')
      object.errors.generate_message(:value, :not_an_integer)
    },
  }, if: :should_validate_in_current_context?

  def format_value
    return if value.blank?

    self.value = value.gsub(/[[:space:]]/, "")
  end
end
