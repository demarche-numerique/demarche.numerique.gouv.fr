# frozen_string_literal: true

class Procedure::Card::RdvComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  def render?
    feature_enabled?(:rdv)
  end

  private

  def badge
    if @procedure.rdv_enabled?
      { label: 'Activée', variant: :success }
    else
      { label: 'Désactivée' }
    end
  end
end
