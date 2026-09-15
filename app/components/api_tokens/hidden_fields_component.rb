# frozen_string_literal: true

module APITokens
  class HiddenFieldsComponent < ApplicationComponent
    def initialize(fields:)
      @fields = fields
    end

    private

    attr_reader :fields
  end
end
