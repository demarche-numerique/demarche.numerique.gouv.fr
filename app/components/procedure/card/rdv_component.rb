# frozen_string_literal: true

class Procedure::Card::RdvComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  def render?
    RdvService.enabled?
  end

  private

  def badge
    if @procedure.rdv_enabled?
      { label: t('.badge.enabled'), variant: :success }
    else
      { label: t('.badge.disabled') }
    end
  end
end
