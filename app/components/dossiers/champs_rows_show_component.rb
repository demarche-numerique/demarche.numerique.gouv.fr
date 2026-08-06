# frozen_string_literal: true

class Dossiers::ChampsRowsShowComponent < ApplicationComponent
  attr_reader :profile
  attr_reader :seen_at
  attr_reader :repetition_heading_level

  def initialize(champs:, profile:, seen_at:, repetition_heading_level: 3)
    @champs, @profile, @seen_at = champs, profile, seen_at
    @repetition_heading_level = repetition_heading_level.to_i.clamp(3, 6)
  end

  def repetition_heading_tag
    "h#{@repetition_heading_level}"
  end

  private

  def row_champs(repetition_champ, row_id)
    repetition_champ.type_de_champ.children.map do
      repetition_champ.dossier.project_champ(_1, row_id:)
    end
  end

  def row_show_component(champ)
    Dossiers::RowShowComponent.new(label: champ.libelle,
      seen_at:, profile:,
      content_class: champ.type_champ,
      updated_at: updated_at_after_deposer(champ),
      updated_by: updated_by(champ),
      source_stream: champ.source_stream)
  end

  def updated_by(champ)
    if usager? && champ.instructeur_buffer_source_stream? && champ.procedure.hide_instructeurs_email?
      nil
    else
      champ.updated_by
    end
  end

  def updated_at_after_deposer(champ)
    return if champ.dossier.depose_at.blank?
    return if champ.new_record?

    if champ.value_updated_at > champ.dossier.depose_at
      champ.value_updated_at
    end
  end

  def number_with_html_delimiter(num)
    # we are using the span delimiter that doesn't insert spaces when copying and pasting the number
    number_with_delimiter(num, delimiter: tag.span(class: 'numbers-delimiter'))
  end

  def blank_key(champ)
    key = champ.mandatory? ? ".blank" : ".blank_optional"
    key += "_attachment" if champ.piece_justificative?

    key
  end

  def visible?(champ)
    return false if champ.header_section? || champ.explication?
    return true if champ.visible?

    if profile == 'instructeur' && champ.public?
      champ.submitted_filled?
    else
      false
    end
  end

  def each_champ(&block)
    @champs.filter { visible?(_1) }.each(&block)
  end

  def usager?
    @profile == 'usager'
  end
end
