# frozen_string_literal: true

class Procedure::Card::SVASVRComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  private

  def badge
    if @procedure.sva_svr_enabled?
      { label: t('.ready'), variant: :success }
    else
      { label: t('.disabled') }
    end
  end
end
