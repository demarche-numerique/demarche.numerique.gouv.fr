# frozen_string_literal: true

class Dossiers::PendingTransfersBannerComponent < ApplicationComponent
  def initialize(count:)
    @count = count
  end

  def render?
    @count.positive?
  end

  attr_reader :count
end
