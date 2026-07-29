# frozen_string_literal: true

class TypesDeChampEditor::HeaderSectionsSummaryComponent < ApplicationComponent
  def initialize(procedure:, is_private:)
    @draft = procedure.draft_revision
    @types_de_champ = is_private ? @draft.types_de_champ_private : @draft.types_de_champ_public
  end

  def sections
    @types_de_champ
      .flat_map { [it] + it.flat_children }
      .filter { it.header_section? || it.repetition? }
  end

  def href(type_de_champ) # used by type de champ editor to anchor elements
    coordinate = @draft.coordinate_for(type_de_champ)
    "##{dom_id(coordinate, :type_de_champ_editor)}"
  end
end
