# frozen_string_literal: true

# Caches the generated "dossier vide" PDF (the printable empty form) in Active Storage
module ProcedureDossierVidePdfConcern
  extend ActiveSupport::Concern

  included do
    has_one_attached :dossier_vide_pdf
  end

  CACHE_KEY_METADATA = 'dossier_vide_pdf_cache_key'
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
  CACHE_EXPIRATION = 1.week

  # The renderer (:typst or :weasyprint) is part of the key: the same
  # attachment caches whichever rendering the procedure's flags select.
  def dossier_vide_pdf_cache_key_for(revision, renderer)
    renderer_key = renderer == :typst ? "typst-#{TEMPLATES_DIGEST}" : renderer.to_s

    ["v#{CACHE_VERSION}", renderer_key, *[self, revision, service].compact.map(&:cache_key_with_version)].join('/')
  end

  def dossier_vide_pdf_fresh?(cache_key)
    blob = dossier_vide_pdf.blob
    return false if blob.nil?

    blob.metadata[CACHE_KEY_METADATA] == cache_key && blob.created_at.after?(CACHE_EXPIRATION.ago)
  end

  def store_dossier_vide_pdf(pdf, cache_key:)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(pdf),
      filename: "#{libelle}.pdf",
      content_type: 'application/pdf',
      metadata: {
        'virus_scan_result' => ActiveStorage::VirusScanner::SAFE,
        CACHE_KEY_METADATA => cache_key,
      }
    )

    # Attaching touches the procedure, which would invalidate the key just stored
    Procedure.no_touching { dossier_vide_pdf.attach(blob) }
  end
end
