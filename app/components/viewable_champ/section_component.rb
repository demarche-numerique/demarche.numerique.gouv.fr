# frozen_string_literal: true

# The champs at the top of a form, of a repetition row or of a header section:
# each header section among them is a section of its own.
class ViewableChamp::SectionComponent < ApplicationComponent
  include ApplicationHelper

  def initialize(champs:, header_section: nil, demande_seen_at:, profile:)
    @champs, @header_section, @demande_seen_at, @profile = champs, header_section, demande_seen_at, profile
  end

  private

  attr_reader :header_section

  def section_id
    @section_id ||= header_section ? dom_id(header_section, :content) : SecureRandom.uuid
  end

  def champs
    @champs.reject(&:header_section?)
  end

  def sections
    @sections ||= @champs.filter(&:header_section?).map do |header_section|
      ViewableChamp::SectionComponent.new(champs: header_section.children, header_section:, demande_seen_at: @demande_seen_at, profile: @profile)
    end
  end

  def reset_tag_for_depth
    return if header_section.nil?

    "reset-h#{header_section.level + 1}"
  end

  def first_level?
    return if header_section.nil?

    header_section.level == 1
  end

  def repetition_heading_level
    relative_level = header_section ? header_section.level : 1
    # there are 2 levels of heading before the repetition heading
    [relative_level + 2, 6].min
  end
end
