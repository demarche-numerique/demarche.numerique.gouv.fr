// Attestation (the decision letter of an accepted or refused dossier).
// `render` receives the JSON payload built by Typst::AttestationPayload,
// decoded by the entry document that TypstService feeds on stdin; the
// bloc-marque images are /images/... files of this compilation root, the
// administration's logo and signature /assets/... files downloaded for the
// rendering.
//
// Payload strings are inserted as text content: the body authored in the
// editor is a tree of typed blocks and inlines (Typst::Tiptap), never Typst
// markup, so the document is structurally immune to content injection.

#import "theme.typ": *

#let render(data) = {
  show: attestation-page.with(title: data.title, footer: data.footer)

  attestation-header(official: data.official_layout, intitule: data.intitule, logo: data.logo, direction: data.direction)

  attestation-body(data.body)

  if data.signature != none {
    signature(bounded-image(data.signature, width: 50mm, height: 50mm))
  }
}
