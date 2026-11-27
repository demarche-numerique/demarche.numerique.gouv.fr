# frozen_string_literal: true

class Dossiers::LinkComponent < ApplicationComponent
  def initialize(champ:)
    @champ = champ
  end

  def call
    href = @champ.href
    return @champ.value if href.nil?

    link_to(href, href, class: 'fr-link', title: helpers.new_tab_suffix(href), **helpers.external_link_attributes)
  end
end
