# frozen_string_literal: true

# The champs at the top of a form, of a repetition row or of a header section:
# each header section among them is a section of its own.
class EditableChamp::SectionComponent < ApplicationComponent
  include ApplicationHelper

  attr_reader :header_section

  def initialize(champs:, header_section: nil, row_number: nil)
    @champs = champs
    @header_section = header_section
    @row_number = row_number
  end

  def render_within_fieldset?
    header_section.present?
  end

  def tag_for_depth
    "h#{header_section.level + 1}"
  end

  private

  def section_for(header_section)
    EditableChamp::SectionComponent.new(champs: header_section.children, header_section:, row_number: @row_number)
  end
end
