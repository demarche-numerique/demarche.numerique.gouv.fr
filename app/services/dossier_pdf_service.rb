# frozen_string_literal: true

# The dossier PDF (usager and instructeur downloads, API v2 pdf endpoint,
# export archives): the native Typst template (lib/typst/dossier.typ) when the
# procedure has the dossier_pdf_typst flag, the Prawn template otherwise. Any
# failure of the Typst path falls back to the proven Prawn rendering, so the
# flag can be rolled out progressively without risking a missing document.
class DossierPdfService
  def self.render(dossier, acls:)
    return render_prawn(dossier, acls:) if !dossier.procedure.feature_enabled?(:dossier_pdf_typst)

    begin
      render_typst(dossier, acls:)
    rescue StandardError => e
      Sentry.capture_exception(e, extra: { dossier_id: dossier.id })
      render_prawn(dossier, acls:)
    end
  end

  def self.render_typst(dossier, acls:)
    TypstService.with_assets do |assets|
      TypstService.render(Typst::DossierPayload.new(dossier, acls:, assets:))
    end
  end

  def self.render_prawn(dossier, acls:)
    ApplicationController.render(template: 'dossiers/show', formats: [:pdf], assigns: { dossier:, acls: })
  end

  private_class_method :render_typst, :render_prawn
end
