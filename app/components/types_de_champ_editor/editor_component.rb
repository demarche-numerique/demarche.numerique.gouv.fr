# frozen_string_literal: true

class TypesDeChampEditor::EditorComponent < ApplicationComponent
  def initialize(revision:, is_annotation: false)
    @revision = revision
    @is_annotation = is_annotation
  end

  private

  def annotations?
    @is_annotation
  end

  def coordinates
    if annotations?
      @revision.private_revision_types_de_champ
    else
      @revision.public_revision_types_de_champ
    end
  end

  def validation_context
    if annotations?
      :types_de_champ_private_editor
    else
      :types_de_champ_public_editor
    end
  end
end
