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

  def splitted_tail
    @champs.map { split_section_champ(it) }
  end

  def tag_for_depth
    "h#{header_section.level + 1}"
  end

  def split_section_champ(champ)
    if champ.header_section?
      [EditableChamp::SectionComponent.new(dossier: @dossier, champs: champ.children, header_section: champ), nil]
    else
      [nil, champ]
    end
  end
end
