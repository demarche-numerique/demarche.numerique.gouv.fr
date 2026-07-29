# frozen_string_literal: true

class EditableChamp::SectionComponent < ApplicationComponent
  include ApplicationHelper

  # champs: champ tree nodes to render at this level (root list, or a section's children)
  # header_section: the champ heading this section (nil at root)
  def initialize(champs:, header_section: nil, row_number: nil)
    @champs = champs
    @header_section = header_section
    @row_number = row_number
  end

  attr_reader :header_section

  def render_within_fieldset?
    header_section.present?
  end

  def tag_for_depth
    "h#{header_section.level + 1}"
  end

  def splitted_tail
    @champs.map do |champ|
      if champ.header_section?
        [nested_section(champ), nil]
      else
        [nil, champ]
      end
    end
  end

  private

  def nested_section(champ)
    self.class.new(champs: champ.children, header_section: champ, row_number: @row_number)
  end
end
