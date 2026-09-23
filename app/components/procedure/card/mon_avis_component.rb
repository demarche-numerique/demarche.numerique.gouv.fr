# frozen_string_literal: true

class Procedure::Card::MonAvisComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  private

  def badge
    if @procedure.monavis_embed.present?
      { label: t('.badge.validated'), variant: :success }
    else
      { label: t('.badge.todo'), variant: :info }
    end
  end
end
