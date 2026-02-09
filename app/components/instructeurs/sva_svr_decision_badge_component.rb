# frozen_string_literal: true

class Instructeurs::SVASVRDecisionBadgeComponent < ApplicationComponent
  attr_reader :dossier
  attr_reader :procedure
  attr_reader :with_label

  def initialize(dossier:, procedure:, with_label: false)
    @dossier = dossier
    @procedure = procedure
    @decision = procedure.sva_svr_configuration.decision.to_sym
    @with_label = with_label
  end

  def render?
    return false unless procedure.sva_svr_enabled?

    [:en_construction, :en_instruction].include? dossier.state.to_sym
  end

  def without_date?
    dossier.sva_svr_decision_on.nil?
  end

  def classes
    class_names(
      'fr-badge fr-badge--sm': true,
      'fr-badge--warning': soon?,
      'fr-badge--info': !without_date? && !soon?
    )
  end

  def soon?
    return false if dossier.sva_svr_decision_on.nil?

    dossier.sva_svr_decision_on < 7.days.from_now.to_date
  end

  def pending_correction?
    dossier.pending_correction?
  end

  def days_count
    (dossier.sva_svr_decision_on - Date.current).to_i
  end

  def sva?
    @decision == :sva
  end

  def svr?
    @decision == :svr
  end

  def label_for_badge
    "#{human_decision} : "
  end

  def title
    if previously_termine?
      t('.previously_termine_title')
    elsif depose_before_configuration?
      t('.depose_before_configuration_title', decision: human_decision)
    elsif without_date?
      t('.manual_decision_title', decision: human_decision)
    elsif pending_correction?
      t(".dossier_terminated_x_days_after_correction", count: days_count)
    else
      t(".dossier_terminated_on", date: DateFormatHelper.long(dossier.sva_svr_decision_on))
    end
  end

  def human_decision
    procedure.sva_svr_configuration.human_decision
  end

  def previously_termine?
    dossier.previously_termine?
  end

  def depose_before_configuration?
    dossier.sva_svr_decision_on.nil? && dossier.sva_svr_decision_triggered_at.nil?
  end
end
