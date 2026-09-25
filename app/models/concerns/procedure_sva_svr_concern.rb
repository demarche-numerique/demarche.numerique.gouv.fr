# frozen_string_literal: true

module ProcedureSVASVRConcern
  extend ActiveSupport::Concern

  included do
    scope :sva_svr, -> { where("sva_svr ->> 'decision' IN (?) AND sva_svr ->> 'disabled_at' IS NULL", ['sva', 'svr']) }
    validate :sva_svr_immutable_on_published, if: :will_save_change_to_sva_svr?
    validate :validates_sva_svr_compatible
    after_update :drop_sva_svr_dates_en_construction, if: -> { saved_change_to_sva_svr? && sva_svr_disabled? }
  end

  def sva_svr_disabled? = sva_svr['disabled_at'].present?

  def sva_svr_disabled_at = sva_svr['disabled_at']&.then { Time.zone.parse(it) }

  def sva_svr_ever_enabled? = [:sva, :svr].include?(decision)

  def sva_svr_enabled?
    sva_svr_ever_enabled? && !sva_svr_disabled?
  end

  def sva_svr_disablable? = !brouillon? && sva_svr_enabled?

  def sva?
    decision == :sva && !sva_svr_disabled?
  end

  def svr?
    decision == :svr && !sva_svr_disabled?
  end

  def sva_svr_configuration
    @sva_svr_configuration ||= SVASVRConfiguration.new(sva_svr.except('disabled_at'))
  end

  def sva_svr_decision
    decision
  end

  def sva_svr_pending_dossiers
    dossiers.state_en_instruction
      .visible_by_administration
      .where.not(sva_svr_decision_on: nil)
      .where(sva_svr_decision_triggered_at: nil)
  end

  def disable_sva_svr
    self.sva_svr = sva_svr.merge('disabled_at' => Time.current.iso8601)
  end

  private

  def drop_sva_svr_dates_en_construction
    dossiers.state_en_construction
      .where.not(sva_svr_decision_on: nil)
      .update_all(sva_svr_decision_on: nil, updated_at: Time.current)
  end

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
    return if !sva_svr_enabled?

    if declarative_with_state.present?
      errors.add(:sva_svr, :declarative_incompatible)
    end
  end
end
