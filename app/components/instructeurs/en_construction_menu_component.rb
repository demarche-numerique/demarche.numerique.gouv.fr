# frozen_string_literal: true

class Instructeurs::EnConstructionMenuComponent < ApplicationComponent
  attr_reader :dossier

  delegate :sva_svr_rule_applies?, to: :dossier

  def initialize(dossier:)
    @dossier = dossier
  end

  def render?
    return true if dossier.may_repasser_en_construction?
    return true if dossier.may_flag_as_pending_correction?

    false
  end

  def menu_label
    if !dossier.may_repasser_en_construction?
      t('.request_correction')
    else
      t(".revert_en_construction")
    end
  end

  def sva_svr_resume_method
    dossier.procedure.sva_svr_configuration.resume
  end

  def sva_svr_human_decision
    dossier.procedure.sva_svr_configuration.human_decision
  end
end
