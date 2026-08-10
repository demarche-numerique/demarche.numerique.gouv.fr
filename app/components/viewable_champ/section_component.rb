# frozen_string_literal: true

class ViewableChamp::SectionComponent < ApplicationComponent
  include ApplicationHelper

  def initialize(dossier:, champs:, header_section: nil, demande_seen_at:, profile:)
    @dossier, @header_section = dossier, header_section
    @demande_seen_at, @profile = demande_seen_at, profile
    @section_champs, @champs = champs.partition(&:header_section?)
  end

  private

  attr_reader :header_section, :champs

  def section_id
    @section_id ||= header_section ? dom_id(header_section, :content) : SecureRandom.uuid
  end

  def sections
    @sections ||= @section_champs.map do |champ|
      ViewableChamp::SectionComponent.new(dossier: @dossier, champs: champ.children, header_section: champ, demande_seen_at: @demande_seen_at, profile: @profile)
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
