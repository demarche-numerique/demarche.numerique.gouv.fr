# frozen_string_literal: true

class ExternalDataException
  KINDS = [:not_found, :technical_error].freeze

  attr_accessor :error, :code, :kind

  def initialize(error:, code:, kind:)
    @error = error
    @code = code
    @kind = kind
  end
end
