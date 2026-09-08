# frozen_string_literal: true

# The attestation PDF (the decision letter of an accepted or refused dossier,
# and its previews in the editor and on the groupe instructeur page). A v2
# template renders by the native Typst template (Typst::AttestationPayload)
# when the procedure has the :attestation_typst flag, by the legacy HTML +
# WeasyPrint rendering otherwise; any failure of the Typst path (payload,
# assets, compiler) is reported and falls back to the legacy rendering, whose
# own failure (WeasyprintService::Error) is left to the caller. A v1 template
# keeps its Prawn rendering.
class AttestationPdfService
  # dossier: none for a preview; groupe_instructeur: whose signature stamps
  # the attestation (the dossier's by default); context: identifiers for the
  # error reports and the WeasyPrint request.
  def self.render(attestation_template, dossier: nil, groupe_instructeur: nil, context: {})
    return render_prawn(attestation_template, dossier:, groupe_instructeur:) if attestation_template.version == 1

    if attestation_template.procedure.feature_enabled?(:attestation_typst)
      begin
        return render_typst(attestation_template, dossier:, groupe_instructeur:)
      rescue StandardError => e
        Sentry.capture_exception(e, extra: { procedure_id: attestation_template.procedure.id, **context })
      end
    end

    render_weasyprint(attestation_template, dossier:, groupe_instructeur:, context:)
  end

  def self.render_typst(attestation_template, dossier:, groupe_instructeur:)
    TypstService.with_assets do |assets|
      TypstService.render(Typst::AttestationPayload.new(attestation_template, assets:, dossier:, groupe_instructeur:))
    end
  end

  def self.render_weasyprint(attestation_template, dossier:, groupe_instructeur:, context:)
    attributes = attestation_template.render_attributes_for(dossier:, groupe_instructeur:)

    html = ApplicationController.render(
      template: 'administrateurs/attestation_template_v2s/show',
      formats: [:html],
      layout: 'attestation',
      assigns: { attestation_template:, body: attributes.fetch(:body), signature: attributes.fetch(:signature) }
    )

    WeasyprintService.generate_pdf(html, { procedure_id: attestation_template.procedure.id, **context })
  end

  def self.render_prawn(attestation_template, dossier:, groupe_instructeur:)
    ApplicationController.render(
      template: 'administrateurs/attestation_templates/show',
      formats: :pdf,
      assigns: { attestation: attestation_template.render_attributes_for(dossier:, groupe_instructeur:) }
    )
  end

  private_class_method :render_typst, :render_weasyprint, :render_prawn
end
