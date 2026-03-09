# frozen_string_literal: true

# Display a widget for uploading, editing and deleting a file attachment
class Attachment::MultipleComponent < ApplicationComponent
  DEFAULT_MAX_ATTACHMENTS = 10

  renders_one :template

  attr_reader :attached_file
  attr_reader :attachments
  attr_reader :champ
  attr_reader :form_object_name
  attr_reader :max
  attr_reader :view_as
  attr_reader :user_can_destroy
  attr_reader :aria_labelledby
  alias user_can_destroy? user_can_destroy

  delegate :size, :empty?, to: :attachments, prefix: true

  def initialize(champ: nil, attached_file:, form_object_name: nil, view_as: :link, user_can_destroy: true, max: nil, aria_labelledby: nil)
    @champ = champ
    @attached_file = attached_file
    @form_object_name = form_object_name
    @view_as = view_as
    @user_can_destroy = user_can_destroy
    @max = max || DEFAULT_MAX_ATTACHMENTS
    @aria_labelledby = aria_labelledby
    @attachments = attached_file.attachments || []
  end

  def each_attachment(&block)
    @attachments.each_with_index(&block)
  end

  def empty_component_id
    champ.present? ? "attachment-multiple-empty-#{champ.public_id}" : "attachment-multiple-empty-generic"
  end

  def auto_attach_url
    champ.present? ? helpers.auto_attach_url(champ) : '#'
  end

  def show_hint?
    champ.present?
  end

  def describedby_hint_id
    return nil if champ.nil?
    "#{champ.focusable_input_id}-pj-hint"
  end

  def max_file_size
    return TypeDeChamp::IDENTITY_FILE_MAX_SIZE if champ&.titre_identite? || champ&.titre_identite_nature?
    champ&.max_file_size_bytes
  end

  def format_families_info
    @format_families_info ||= if champ.nil? || !champ.piece_justificative?
      []
    else
      tdc = champ.type_de_champ
      if tdc.titre_identite_nature? || tdc.RIB? || !tdc.pj_limit_formats? || tdc.pj_format_families.blank?
        []
      else
        tdc.pj_format_families.map(&:to_sym).filter_map do |key|
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
    tdc.titre_identite_nature? || tdc.RIB?
  end

  def exhaustive_formats
    return nil unless show_exhaustive_formats?

    champ.type_de_champ.allowed_extensions.join(', ')
  end

  def formats_accepted_text
    format_families_info.map { |f| "#{f[:label]} (#{f[:top_formats]}...)" }.join(', ')
  end

  def tooltip_id
    return nil if champ.nil?

    "#{champ.focusable_input_id}-formats-tooltip"
  end
end
