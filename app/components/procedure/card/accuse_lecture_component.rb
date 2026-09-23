# frozen_string_literal: true

class Procedure::Card::AccuseLectureComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  private

  def badge
    if @procedure.accuse_lecture.present?
      { label: 'Activé', variant: :success }
    else
      { label: 'Désactivé' }
    end
  end
end
