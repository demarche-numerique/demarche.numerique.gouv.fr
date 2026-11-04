# frozen_string_literal: true

class Champs::LinkChamp < Champs::TextChamp
  normalizes :value, with: -> (value) { URLValidator.normalize(value) }

  validates :value, url: true, allow_blank: true, if: :should_validate_in_current_context?
end
