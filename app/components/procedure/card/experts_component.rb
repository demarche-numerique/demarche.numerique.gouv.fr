# frozen_string_literal: true

class Procedure::Card::ExpertsComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  def configured?
    @procedure.allow_expert_review?
  end

  private

  def badge
    if configured?
      { label: t('.configured'), variant: :success }
    else
      { label: t('.unconfigured'), variant: :info }
    end
  end
end
