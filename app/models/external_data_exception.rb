# frozen_string_literal: true

class ExternalDataException
  attr_accessor :error, :code

  def initialize(error:, code:)
    @error = error
    @code = code
  end
end
