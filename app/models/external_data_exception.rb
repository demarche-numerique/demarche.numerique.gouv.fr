# frozen_string_literal: true

class ExternalDataException
  KINDS = [:not_found, :technical_error].freeze

  attr_accessor :error, :code, :kind

  def initialize(error:, code:, kind: nil)
    @error = error
    @code = code
    @kind = kind
  end

  def not_found?
    kind == :not_found || code == 404
  end
end
