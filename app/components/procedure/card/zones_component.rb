# frozen_string_literal: true

class Procedure::Card::ZonesComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  private

  def badge
    if @procedure.zones.size >= 1
      { label: 'Validé', variant: :success }
    else
      { label: 'À faire', variant: :warning }
    end
  end
end
