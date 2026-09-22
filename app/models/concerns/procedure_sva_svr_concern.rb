# frozen_string_literal: true

module ProcedureSVASVRConcern
  extend ActiveSupport::Concern

  included do
    scope :sva_svr, -> { where("sva_svr ->> 'decision' IN (?) AND sva_svr ->> 'disabled_at' IS NULL", ['sva', 'svr']) }
    validate :sva_svr_immutable_on_published, if: :will_save_change_to_sva_svr?
    validate :validates_sva_svr_compatible
  end

  def sva_svr_disabled? = sva_svr['disabled_at'].present?

  def sva_svr_ever_enabled? = [:sva, :svr].include?(decision)

  def sva_svr_enabled?
    sva_svr_ever_enabled? && !sva_svr_disabled?
  end

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

    errors.add(:sva_svr, :immutable)
  end

  def validates_sva_svr_compatible
    return if !sva_svr_enabled?

    if declarative_with_state.present?
      errors.add(:sva_svr, :declarative_incompatible)
    end
  end
end
