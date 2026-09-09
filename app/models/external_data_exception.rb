# frozen_string_literal: true

class ExternalDataException
  # The API answered about this identifier and will not answer differently
  # later: nonexistent (404), unprocessable (422), non-diffusible (451).
  DEFINITIVE_CODES = [404, 422, 451].freeze

  attr_accessor :error, :code

  def initialize(error:, code:)
    @error = error
    @code = code
  end

  def not_found?
    code == 404
  end

  def definitive?
    code.in?(DEFINITIVE_CODES)
  end
end
