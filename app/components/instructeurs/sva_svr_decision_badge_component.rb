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

  def situation
    @situation ||= if previously_termine?
      :previously_termine
    elsif depose_before_configuration?
      :depose_before_configuration
    elsif without_date?
      :no_date
    elsif pending_correction?
      :pending_correction
    else
      :scheduled
    end
  end

  def badge_text
    case situation
    when :previously_termine, :no_date then t('.manual_decision')
    when :depose_before_configuration then t('.depose_before_configuration', decision: human_decision)
    when :pending_correction then t('.remaining_days_after_correction', count: days_count)
    when :scheduled then t('.in_days', count: days_count)
    end
  end

  def title
    case situation
    when :previously_termine then t('.previously_termine_title')
    when :depose_before_configuration then t('.depose_before_configuration_title', decision: human_decision)
    when :no_date then t('.manual_decision_title', decision: human_decision)
    when :pending_correction then t('.dossier_terminated_x_days_after_correction', count: days_count)
    when :scheduled then t('.dossier_terminated_on', date: helpers.l(dossier.sva_svr_decision_on))
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
