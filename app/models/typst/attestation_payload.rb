# frozen_string_literal: true

# Payload of an attestation (lib/typst/root/attestation.typ), the decision
# letter an administration authors in the tiptap editor: the letterhead it
# chose (the official bloc-marque or its own logo, a direction, a footer),
# the body with the dossier's values in place of the mentions, laid out by
# Typst::Tiptap, and the signature of the groupe instructeur.
class Typst::AttestationPayload < Typst::Payload
  # The placeholders of the HTML rendering, for a template left unnamed.
  DEFAULT_INTITULE = "INTITULE de\nVOTRE INSTITUTION"
  DEFAULT_LOGO_ALT = 'Logo de l’administration'
  DEFAULT_TITLES = { 'acceptation' => 'Attestation d’acceptation', 'refus' => 'Attestation de refus' }.freeze

  attr_reader :attestation_template, :dossier, :groupe_instructeur, :assets

  # dossier: the accepted or refused dossier, none for a preview (the
  #   mentions then show as placeholders)
  # groupe_instructeur: whose signature stamps the attestation, the dossier's
  #   by default
  # assets: TypstService::Assets, for the logo and the signature
  def initialize(attestation_template, assets:, dossier: nil, groupe_instructeur: nil)
    super()
    @attestation_template = attestation_template
    @dossier = dossier
    @groupe_instructeur = groupe_instructeur || dossier&.groupe_instructeur
    @assets = assets
  end

  def build
    body = Typst::Tiptap.from_document(attestation_template.resolved_json_body(dossier))

    {
      # Pinned: the letter is authored in French, whatever the reader's locale.
      lang: 'fr',
      title: document_title(body),
      official_layout: attestation_template.official_layout?,
      intitule: lines(attestation_template.label_logo.presence || DEFAULT_INTITULE),
      logo: assets.image(attestation_template.logo, alt: attestation_template.label_logo.presence || DEFAULT_LOGO_ALT),
      direction: lines(attestation_template.label_direction),
      footer: lines(attestation_template.footer),
      body:,
      signature: assets.image(attestation_template.signature_for(groupe_instructeur), alt: 'Signature'),
    }
  end

  private

  # The PDF's title (required by PDF/UA): the document's own title, the kind
  # of decision when the admin left it blank.
  def document_title(body)
    title = body.find { it[:type] == 'heading' && it[:level] == 1 }
    title ? Typst::Tiptap.plain(title[:content]) : DEFAULT_TITLES.fetch(attestation_template.kind)
  end

  def lines(text)
    text.to_s.lines.map(&:strip).compact_blank
  end
end
