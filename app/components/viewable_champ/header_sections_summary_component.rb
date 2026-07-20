# frozen_string_literal: true

class ViewableChamp::HeaderSectionsSummaryComponent < ApplicationComponent
  attr_reader :header_sections

  def initialize(dossier:, is_private:)
    @dossier = dossier
    @is_private = is_private

    @header_sections = if is_private
      dossier.root_types_de_champ_private
    else
      dossier.root_types_de_champ_public
    end.filter(&:header_section?)
  end

  def render? = header_sections.any?

  def href(header_section) # used by viewable champs to anchor elements
    "##{header_section.html_id}"
  end
end
