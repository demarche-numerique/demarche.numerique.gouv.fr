# frozen_string_literal: true

class TagsLegendModalComponent < ApplicationComponent
  attr_reader :modal_id

  def initialize(modal_id:)
    @modal_id = modal_id
  end
end
