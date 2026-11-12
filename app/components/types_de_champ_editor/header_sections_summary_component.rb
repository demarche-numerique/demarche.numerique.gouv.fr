# frozen_string_literal: true

class TypesDeChampEditor::HeaderSectionsSummaryComponent < ApplicationComponent
  def initialize(procedure:, is_private:)
    @procedure = procedure
    @is_private = is_private
  end

  def header_sections
    type_de_champs = if @is_private
      draft_revision.private_root_type_de_champs
    else
      draft_revision.public_root_type_de_champs
    end

    type_de_champs.filter(&:header_section?)
  end

  # the editor anchors its elements on the coordinates
  def href(header_section)
    "##{dom_id(draft_revision.coordinate_for(header_section), :type_de_champ_editor)}"
  end

  private

  def draft_revision = @procedure.draft_revision
end
