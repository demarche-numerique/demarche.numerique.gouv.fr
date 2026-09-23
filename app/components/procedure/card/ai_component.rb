# frozen_string_literal: true

class Procedure::Card::AiComponent < ApplicationComponent
  attr_reader :procedure

  def initialize(procedure:)
    @procedure = procedure
  end

  def render?
    procedure.feature_enabled?(:llm_nightly_improve_procedure)
  end

  def improved?
    any_tunnel_finished?
  end

  def any_tunnel_finished?
    @any_tunnel_finished ||= LLM::TunnelQuery.any_finished?(procedure_revision_id: procedure.draft_revision.id)
  end

  private

  def badge
    if improved?
      { label: 'Amélioré', variant: :success }
    else
      { label: 'À faire', variant: :warning }
    end
  end
end
