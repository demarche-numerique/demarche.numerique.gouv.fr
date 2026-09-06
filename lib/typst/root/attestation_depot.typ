// Attestation de depot. `render` receives the JSON payload built by
// DossierAttestationDepotConcern, decoded by the entry document that
// TypstService feeds on stdin; images are referenced as /images/... in this
// compilation root.
//
// Payload strings are inserted as text content: Typst never interprets them
// as markup, so the document is structurally immune to content injection.

#import "theme.typ": *

#let render(data) = {
  show: letterhead.with(
    title: data.title,
    lang: data.lang,
    marianne: data.marianne,
    logo: data.logo,
    sender: data.sender,
  )

  document-head(data.title, data.procedure, date: data.date)

  depot-description[#data.description]

  for section in data.sections {
    depot-section({
      heading(level: 2, section.title)
      key-value(..section.rows)
    })
  }

  signature[#par[#data.signature]]
}
