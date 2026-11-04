# frozen_string_literal: true

class Dsfr::SidemenuComponent < ApplicationComponent
  renders_many :links, "LinkComponent"

  class LinkComponent < ApplicationComponent
    attr_reader :name, :url, :icon, :count, :count_label
    def initialize(name:, url:, icon: nil, count: nil, count_label: nil)
      @name = name
      @url = url
      @icon = icon
      @count = count
      @count_label = count_label
    end

    def count? = count&.positive?
  end

  def active?(url)
    current_page?(url)
  end
end
