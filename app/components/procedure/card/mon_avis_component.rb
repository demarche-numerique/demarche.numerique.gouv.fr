# frozen_string_literal: true

class Procedure::Card::MonAvisComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  private

  def badge
    if @procedure.monavis_embed.present?
      { label: 'Validé', variant: :success }
    else
      { label: 'À configurer', variant: :info }
    end
  end
end
