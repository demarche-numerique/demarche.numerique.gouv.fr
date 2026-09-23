# frozen_string_literal: true

class Procedure::Card::LabelsComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  private

  def badge
    if @procedure.labels.present?
      { label: 'Configuré', variant: :success }
    else
      { label: 'À configurer', variant: :info }
    end
  end
end
