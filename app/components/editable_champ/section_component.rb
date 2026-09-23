# frozen_string_literal: true

class EditableChamp::SectionComponent < ApplicationComponent
  include ApplicationHelper
  include TreeableConcern

  def initialize(dossier:, nodes: nil, type_de_champs: nil, row_id: nil, row_number: nil)
    nodes ||= to_tree(type_de_champs:)
    @dossier = dossier
    @row_id = row_id
    @row_number = row_number
    @nodes = to_fieldset(nodes:)
  end

  def render_within_fieldset?
    first_champ_is_an_header_section?
  end

  def header_section
    node = @nodes.first
    @dossier.project_champ(node, row_id: @row_id) if node.is_a?(TypeDeChamp) && node.header_section?
  end

  def splitted_tail
    tail.map { split_section_champ(_1) }
  end

  def tail
    return @nodes if !first_champ_is_an_header_section?
    _, *rest_of_champ = @nodes

    rest_of_champ
  end

  def tag_for_depth
    "h#{section_level + 1}"
  end

  def split_section_champ(node)
    case node
    when EditableChamp::SectionComponent
      [node, nil]
    else
      [nil, @dossier.project_champ(node, row_id: @row_id)]
    end
  end

  private

  # the level in the whole form: a section within a repetition sits under the
  # sections holding the repetition
  def section_level
    header_section.level + header_section.enclosing_repetition&.level.to_i
  end

  def to_fieldset(nodes:)
    nodes.map { _1.is_a?(Array) ? EditableChamp::SectionComponent.new(dossier: @dossier, nodes: _1, row_id: @row_id) : _1 }
  end

  def first_champ_is_an_header_section?
    header_section.present?
  end
end
