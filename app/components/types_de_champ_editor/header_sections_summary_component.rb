# frozen_string_literal: true

class TypesDeChampEditor::HeaderSectionsSummaryComponent < ApplicationComponent
  def initialize(procedure:, is_private:)
    @procedure = procedure
    @is_private = is_private
  end

  # Header sections and repetitions in document order, as [type_de_champ, depth]
  # pairs. Depth is the position in the tree; like TypeDeChampBase#level, it
  # can differ from the stored header_section_level when levels are skipped.
  def sections
    @sections ||= flatten_sections(root_types_de_champ, 1)
  end

  def href(type_de_champ) # used by type de champ editor to anchor elements
    "##{dom_id(revision.coordinate_for(type_de_champ), :type_de_champ_editor)}"
  end

  private

  def revision = @procedure.draft_revision

  def root_types_de_champ
    @is_private ? revision.types_de_champ_private : revision.types_de_champ_public
  end

  def flatten_sections(types_de_champ, depth)
    types_de_champ.filter { it.header_section? || it.repetition? }.flat_map do |type_de_champ|
      [[type_de_champ, depth], *flatten_sections(type_de_champ.children, depth + 1)]
    end
  end
end
