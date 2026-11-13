# frozen_string_literal: true

class Champs::LinkChamp < Champs::TextChamp
  normalizes :value, with: -> (value) { URLValidator.normalize(value) }

  validates :value, url: true, allow_blank: true, if: :should_validate_in_current_context?

  # the annotation autosave keeps an invalid value: never render it as a href
  def href
    value if value.present? && Addressable::URI.parse(value).normalized_scheme.in?(['http', 'https'])
  rescue Addressable::URI::InvalidURIError
    nil
  end
end
