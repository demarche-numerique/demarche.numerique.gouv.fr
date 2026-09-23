# frozen_string_literal: true

class Procedure::Card::ChorusComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  def render?
    @procedure.chorusable?
  end

  def complete?
    @procedure.chorus_configuration.complete?
  end

  private

  def badge
    if complete?
      { label: 'Configuré', variant: :success }
    else
      { label: 'À compléter', variant: :warning }
    end
  end
end
