# frozen_string_literal: true

class EditableChamp::SectionComponent < ApplicationComponent
  include ApplicationHelper
  include TreeableConcern

  def initialize(dossier:, types_de_champ: nil, header_section: nil, row_id: nil, row_number: nil)
    @dossier, @header_section, @row_id, @row_number = dossier, header_section, row_id, row_number
    @nodes = types_de_champ ? to_tree_roots(types_de_champ:) : header_section.children(dossier.revision)
  end

  def render_within_fieldset?
    @header_section.present?
  end

  def header_section
    @dossier.project_champ(@header_section, row_id: @row_id) if @header_section
  end

  def splitted_tail
    @nodes.map { split_section_champ(it) }
  end

  def tag_for_depth
    "h#{header_section.level + 1}"
  end

  def split_section_champ(type_de_champ)
    if type_de_champ.header_section?
      [EditableChamp::SectionComponent.new(dossier: @dossier, header_section: type_de_champ, row_id: @row_id), nil]
    else
      [nil, @dossier.project_champ(type_de_champ, row_id: @row_id)]
    end
  end
end
