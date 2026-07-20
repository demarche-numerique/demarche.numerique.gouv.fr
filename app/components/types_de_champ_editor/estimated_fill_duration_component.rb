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
    !annotations? && @revision.types_de_champ_public.present?
  end

  def estimated_fill_duration_minutes
    seconds = @revision.estimated_fill_duration
    minutes = (seconds / 60.0).round
    [1, minutes].max
  end
end
