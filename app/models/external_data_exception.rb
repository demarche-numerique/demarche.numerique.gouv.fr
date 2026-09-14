# frozen_string_literal: true

class ExternalDataException
  # Our own credentials are at fault, not the identifier: no retry converges.
  CREDENTIALS_CODES = [401, 403].freeze

  attr_accessor :error, :code

  def initialize(error:, code:)
    @error = error
    @code = code
  end

  def not_found?
    code == 404
  end
end
