# frozen_string_literal: true

class Procedure::Card::InstructeursComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  private

  def badge
    if @procedure.routing_enabled? && @procedure.groupe_instructeurs.any?(&:routing_to_configure?)
      { label: 'À faire', variant: :warning }
    elsif @procedure.instructeurs.present?
      { label: 'Validé', variant: :success }
    else
      { label: 'À faire', variant: :warning }
    end
  end

  def count
    @procedure.routing_enabled? ? @procedure.groupe_instructeurs.size : @procedure.instructeurs.size
  end

  def title
    if @procedure.groupe_instructeurs.many?
      t('.routee.title', count: @procedure.groupe_instructeurs.size)
    else
      t('.title', count: @procedure.instructeurs.size)
    end
  end
end
