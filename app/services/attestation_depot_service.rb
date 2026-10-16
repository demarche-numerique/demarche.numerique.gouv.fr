# frozen_string_literal: true

# The attestation de depot PDF, by the renderer the procedure's
# :attestation_depot_typst flag selects: the native Typst template
# (Typst::AttestationDepotPayload) or the legacy HTML + WeasyPrint rendering.
# Any failure of the Typst path (compiler, payload) is reported and falls
# back to the legacy rendering, whose own failure (WeasyprintService::Error)
# is left to the caller.
class AttestationDepotService
  def self.render(dossier)
    if dossier.procedure.feature_enabled?(:attestation_depot_typst)
      begin
        return TypstService.render(Typst::AttestationDepotPayload.new(dossier))
      rescue StandardError => e
        Sentry.capture_exception(e, extra: { dossier_id: dossier.id })
      end
    end

    render_weasyprint(dossier)
  end

  def self.render_weasyprint(dossier)
    html = ApplicationController.render(
      template: 'users/dossiers/attestation_depot',
      layout: 'attestation',
      assigns: { dossier: }
    )

    WeasyprintService.generate_pdf(html, { procedure_id: dossier.procedure.id, dossier_id: dossier.id })
  end

  private_class_method :render_weasyprint
end
