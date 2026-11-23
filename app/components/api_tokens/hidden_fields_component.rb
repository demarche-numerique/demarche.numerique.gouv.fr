# frozen_string_literal: true

module APITokens
  class HiddenFieldsComponent < ApplicationComponent
    def initialize(form:, except: [])
      @form = form
      @except = except
    end

    private

    attr_reader :form

    def attributes
      form.object.attributes.compact.except(*@except.map(&:to_s))
    end
  end
end
