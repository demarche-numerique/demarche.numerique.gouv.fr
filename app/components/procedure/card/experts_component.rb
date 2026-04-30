# frozen_string_literal: true

class Procedure::Card::ExpertsComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  def configured?
    @procedure.allow_expert_review?
  end
end
