# frozen_string_literal: true

class Dossiers::PendingCorrectionCheckboxComponent < ApplicationComponent
  attr_reader :dossier

  # Pass the editing fork origin, ie. dossier en construction holding the correction
  def initialize(dossier:)
    @dossier = dossier
  end

  def render?
    return false unless dossier.sva_svr_rule_applies?

    dossier.pending_correction?
  end

  def error? = dossier.errors.include?(:pending_correction)

  def error_message
    dossier.errors.generate_message(:pending_correction, :blank)
  end

  def check_box_aria_attributes
    return unless error?

    { describedby: :dossier_pending_correction_error_messages }
  end
end
