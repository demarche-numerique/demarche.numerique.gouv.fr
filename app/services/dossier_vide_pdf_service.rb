# frozen_string_literal: true

# The dossier vide PDF (the printable empty form of a revision), by the
# renderer the procedure's flags select, each newer one falling back to the
# previous on any failure (reported to Sentry): the native Typst template
# (:dossier_vide_typst, Typst::DossierVidePayload), the HTML + WeasyPrint
# rendering (:dossier_vide_weasyprint, Dossiers::DossierVidePdfComponent),
# the Prawn template. A published revision's PDF is cached in Active Storage
# (ProcedureDossierVidePdfConcern) behind a key built from everything it
# depends on; the draft ("test") PDF is never cached.
class DossierVidePdfService
  # Bump when a rendering changes outside what the key already tracks (the
  # WeasyPrint component and stylesheet, the Typst payload builder, helpers,
  # fonts) and the already cached PDF should be invalidated without waiting
  # for the expiration. v2: the renderer joined the key.
  CACHE_VERSION = 2
  # Typst template edits invalidate the cache on their own: their digest is
  # part of the key.
  TEMPLATES_DIGEST = Digest::SHA256.hexdigest(
    %w[dossier_vide theme].map { TypstService::ROOT.join("#{it}.typ").read }.join
  ).first(12)

  def self.render(revision)
    procedure = revision.procedure

    if procedure.feature_enabled?(:dossier_vide_typst)
      begin
        return cached(revision, :typst)
      rescue StandardError => e
        Sentry.capture_exception(e, extra: { procedure_id: procedure.id })
      end
    end

    if procedure.feature_enabled?(:dossier_vide_weasyprint)
      begin
        return cached(revision, :weasyprint)
      rescue StandardError => e
        Sentry.capture_exception(e, extra: { procedure_id: procedure.id })
      end
    end

    render_prawn(revision)
  end

  # The renderer (:typst or :weasyprint) is part of the key: the same
  # attachment caches whichever rendering the procedure's flags select.
  def self.cache_key(revision, renderer)
    procedure = revision.procedure
    renderer_key = renderer == :typst ? "typst-#{TEMPLATES_DIGEST}" : renderer.to_s

    ["v#{CACHE_VERSION}", renderer_key, *[procedure, revision, procedure.service].compact.map(&:cache_key_with_version)].join('/')
  end

  def self.cached(revision, renderer)
    return render_with(revision, renderer) if revision.draft?

    procedure = revision.procedure
    cache_key = cache_key(revision, renderer)

    return procedure.dossier_vide_pdf.download if procedure.dossier_vide_pdf_fresh?(cache_key)

    render_with(revision, renderer).tap do |pdf|
      procedure.store_dossier_vide_pdf(pdf, cache_key:)
    rescue StandardError => e
      # A storage failure must not cost the user the PDF just rendered.
      Sentry.capture_exception(e, extra: { procedure_id: procedure.id })
    end
  end

  def self.render_with(revision, renderer)
    case renderer
    when :typst
      TypstService.render(Typst::DossierVidePayload.new(revision))
    when :weasyprint
      html = ApplicationController.render(Dossiers::DossierVidePdfComponent.new(revision:), layout: 'dossier_vide_pdf')

      WeasyprintService.generate_pdf(html, { procedure_id: revision.procedure.id })
    end
  end

  def self.render_prawn(revision)
    ApplicationController.render(template: 'dossiers/dossier_vide', formats: [:pdf], assigns: { revision:, procedure: revision.procedure })
  end

  private_class_method :cached, :render_with, :render_prawn
end
