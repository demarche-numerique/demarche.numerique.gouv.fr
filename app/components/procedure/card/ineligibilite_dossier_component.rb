# frozen_string_literal: true

class Procedure::Card::IneligibiliteDossierComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  def ready?
    @procedure.draft_revision
      .conditionable_type_de_champs
      .present? && @procedure.draft_revision.ineligibilite_enabled
  end

  def error?
    !@procedure.draft_revision.validate(:ineligibilite_rules_editor)
  end

  def completed?
    @procedure.draft_revision.ineligibilite_enabled
  end

  private

  def badge
    if !ready?
      { label: t('.state.pending') }
    elsif error?
      { label: 'À modifier', variant: :error }
    else
      { label: t('.state.completed'), variant: :success }
    end
  end
end
