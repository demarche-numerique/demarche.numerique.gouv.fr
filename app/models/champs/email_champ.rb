# frozen_string_literal: true

class Champs::EmailChamp < Champs::TextChamp
  validates :value, allow_blank: true, strict_email: true, if: :should_validate_in_current_context?

  def value=(value)
    super(value.present? ? EmailSanitizableConcern::EmailSanitizer.sanitize(value) : value)
  end
end
