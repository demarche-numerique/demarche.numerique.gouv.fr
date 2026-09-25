# frozen_string_literal: true

class Procedure::Card::AttestationComponent < ApplicationComponent
  def initialize(procedure:, kind:)
    @procedure = procedure
    @kind = kind
  end

  private

  def edit_attestation_path
    if (@kind == AttestationTemplate.kinds.fetch(:acceptation)) && (@procedure.attestation_acceptation_template&.version == 1)
      helpers.edit_admin_procedure_attestation_template_path(@procedure)
    else
      helpers.edit_admin_procedure_attestation_template_v2_path(@procedure, attestation_kind: @kind)
    end
  end

  def badge
    if !@procedure.published_attestation_template_for(@kind)&.activated?
      { label: t('.badge.disabled') }
    elsif error_messages.present?
      { label: t('.badge.error'), variant: :warning }
    else
      { label: t('.badge.enabled'), variant: :success }
    end
  end

  def error_messages
    if @kind == AttestationTemplate.kinds.fetch(:acceptation)
      @procedure.errors.messages_for(:attestation_acceptation_template).to_sentence
    elsif @kind == AttestationTemplate.kinds.fetch(:refus)
      @procedure.errors.messages_for(:attestation_refus_template).to_sentence
    end
  end
end
