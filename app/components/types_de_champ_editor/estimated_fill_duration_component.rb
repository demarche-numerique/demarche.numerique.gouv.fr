# frozen_string_literal: true

class TypesDeChampEditor::EstimatedFillDurationComponent < ApplicationComponent
  def initialize(revision:, is_annotation: false)
    @revision = revision
    @is_annotation = is_annotation
  end

  private

  def annotations?
    @is_annotation
  end

  def render?
    @revision.procedure.estimated_duration_visible?
  end

  def show?
    !annotations? && @revision.public_root_type_de_champs.present?
  end

  def estimated_fill_minutes_text = helpers.estimated_fill_minutes_text(@revision)
end
