# frozen_string_literal: true

class AttestationPdfGenerationJob < ApplicationJob
  queue_as :critical

  discard_on ActiveRecord::RecordNotFound

  def perform(dossier)
    template = template_for(dossier)
    return unless template&.activated?

    template.generate_attestation_for(dossier)
  end

  private

  def template_for(dossier)
    kind = if dossier.accepte?
      :acceptation
    elsif dossier.refuse?
      :refus
    end

    dossier.attestation_template_for(AttestationTemplate.kinds.fetch(kind))
  end
end
