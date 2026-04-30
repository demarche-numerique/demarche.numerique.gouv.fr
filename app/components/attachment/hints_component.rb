# frozen_string_literal: true

# Displays upload hints: max file size, allowed formats, identity document requirements.
# Centralizes validation rules presentation.
class Attachment::HintsComponent < ApplicationComponent
  attr_reader :champ

  delegate :max_file_size, :allowed_extensions, to: :validation

  def initialize(champ:, attached_file: nil, show_identity_hint: false, html_id: nil, max: nil)
    @champ = champ
    @attached_file = attached_file
    @show_identity_hint = show_identity_hint
    @html_id = html_id
    @max = max
  end

  def validation
    @validation ||= Attachment::Validation.new(attached_file: @attached_file)
  end

  def show_identity_hint?
    @champ&.titre_identite?
  end

  def render?
    max_file_size.present? || allowed_extensions.present? || show_identity_hint?
  end

  def format_families_info
    @format_families_info ||= if champ.nil? || !champ.piece_justificative?
      []
    else
      tdc = champ.type_de_champ
      families = tdc.pj_format_families.map(&:to_sym)
      if tdc.titre_identite? || tdc.rib? || !tdc.pj_limit_formats? || families.blank? || families.sort == FORMAT_FAMILIES.keys.sort
        []
      else
        families.filter_map do |key|
          label = I18n.t("activerecord.attributes.type_de_champ.format_families.#{key}", default: key.to_s.humanize).downcase
          top = FORMAT_FAMILY_TOP_FORMATS[key]
          all = FORMAT_FAMILY_EXAMPLES[key]
          next if top.nil?

          { key:, label:, top_formats: top, all_formats: all }
        end
      end
    end
  end

  def show_format_families?
    format_families_info.present?
  end

  def show_exhaustive_formats?
    return false if champ.nil? || !champ.piece_justificative?

    tdc = champ.type_de_champ
    tdc.titre_identite? || tdc.rib?
  end

  def exhaustive_formats
    return nil unless show_exhaustive_formats?

    tdc = champ.type_de_champ
    NATURE_DISPLAY_FORMATS[tdc.nature&.to_sym] || tdc.allowed_extensions.join(', ')
  end

  def formats_accepted_text
    format_families_info.map { |f| "#{f[:label]} (#{f[:top_formats]}...)" }.join(', ')
  end

  def tooltip_id
    return nil if champ.nil?

    "#{champ.focusable_input_id}-formats-tooltip"
  end
end
