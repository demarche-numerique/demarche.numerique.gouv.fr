# frozen_string_literal: true

class Procedure::Card::ZonesComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  private

  def badge
    if @procedure.zones.size >= 1
      { label: t('.badge.validated'), variant: :success }
    else
      { label: t('.badge.todo'), variant: :warning }
    end
  end
end
