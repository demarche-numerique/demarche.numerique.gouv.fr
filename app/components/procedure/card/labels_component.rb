# frozen_string_literal: true

class Procedure::Card::LabelsComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  private

  def badge
    if @procedure.labels.present?
      { label: t('.badge.configured'), variant: :success }
    else
      { label: t('.badge.todo'), variant: :info }
    end
  end
end
