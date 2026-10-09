# frozen_string_literal: true

module ProcedureSVASVRConcern
  extend ActiveSupport::Concern

  included do
    scope :sva_svr, -> { where("sva_svr ->> 'decision' IN (?)", ['sva', 'svr']) }
    validate :sva_svr_immutable_on_published, if: :will_save_change_to_sva_svr?
    validate :validates_sva_svr_compatible
  end

  def sva_svr_rule? = sva? || svr?

  def sva_svr_rule_disabled? = sva_svr['disabled_at'].present?

  def sva_svr_rule_disabled_at = Time.zone.parse(sva_svr['disabled_at'])

  def sva_svr_enabled?
    sva_svr_rule? && !sva_svr_rule_disabled?
  end

  def sva?
    decision == :sva
  end

  def svr?
    decision == :svr
  end

  def sva_svr_configuration
    @sva_svr_configuration ||= SVASVRConfiguration.new(sva_svr.except('disabled_at'))
  end

  def sva_svr_decision
    decision
  end

  def sva_svr_pending_dossiers
    dossiers.state_en_construction_ou_instruction.where.not(sva_svr_decision_on: nil)
  end

  def sva_svr_rule_running?
    sva_svr_enabled? || (sva_svr_rule_disabled? && sva_svr_pending_dossiers.exists?)
  end

  private

  def decision
    sva_svr.fetch("decision", nil)&.to_sym
  end

  def decision_was
    sva_svr_was.fetch("decision", nil)&.to_sym
  end

  def sva_svr_immutable_on_published
    return if brouillon?
    return if [:sva, :svr].exclude?(decision_was)

    if sva_svr_was['disabled_at'].present?
      errors.add(:sva_svr, :definitive)
    elsif sva_svr['disabled_at'].blank? || sva_svr.except('disabled_at') != sva_svr_was.except('disabled_at')
      errors.add(:sva_svr, :immutable)
    end
  end

  def validates_sva_svr_compatible
    return if declarative_with_state.blank?

    if sva_svr_enabled?
      errors.add(:sva_svr, :declarative_incompatible)
    elsif sva_svr_rule_disabled? && will_save_change_to_declarative_with_state?
      count = sva_svr_pending_dossiers.count
      errors.add(:sva_svr, :declarative_incompatible_until_decided, count:) if count > 0
    end
  end
end
