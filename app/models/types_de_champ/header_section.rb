# frozen_string_literal: true

class TypesDeChamp::HeaderSection < TypeDeChamp
  def self.category = STRUCTURE
  def self.option_keys = [:header_section_level]

  store_accessor :options, :header_section_level

  def fillable? = false
  def description_configurable? = false
  def has_label? = false
  def tags_for_template = [].freeze

  def header_section_level_value
    if header_section_level.presence
      header_section_level.to_i
    else
      1
    end
  end

  def check_coherent_header_level(upper_tdcs)
    previous_level = previous_section_level(upper_tdcs)
    current_level = header_section_level_value.to_i

    difference = current_level - previous_level
    if current_level > previous_level && difference != 1
      I18n.t('activerecord.errors.type_de_champ.attributes.header_section_level.gap_error', level: current_level - previous_level - 1)
    else
      nil
    end
  end

  def level_for_revision(revision)
    parent_type_de_champ = revision.parent_of(self)

    if parent_type_de_champ.present?
      header_section_level_value.to_i + parent_type_de_champ.current_section_level(revision)
    elsif header_section_level_value
      header_section_level_value.to_i
    else
      0
    end
  end
end
