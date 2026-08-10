# frozen_string_literal: true

class EditableChamp::SectionComponent < ApplicationComponent
  include ApplicationHelper

  def initialize(dossier:, champs:, header_section: nil, row_number: nil)
    @dossier, @champs, @header_section, @row_number = dossier, champs, header_section, row_number
  end

  attr_reader :header_section

  def render_within_fieldset?
    header_section.present?
  end

  # The section's champs in order, as [section, champ] pairs: a header section
  # becomes a nested SectionComponent, any other champ stays a champ.
  def entries
    @champs.map { section_or_champ(it) }
  end

  def tag_for_depth
    "h#{header_section.level + 1}"
  end

  def section_or_champ(champ)
    if champ.header_section?
      [EditableChamp::SectionComponent.new(dossier: @dossier, champs: champ.children, header_section: champ), nil]
    else
      [nil, champ]
    end
  end
end
