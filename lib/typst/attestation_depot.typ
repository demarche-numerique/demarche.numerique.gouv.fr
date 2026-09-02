// Attestation de depot, rendered from a JSON payload written by TypstService
// to a tempfile whose path arrives as --input data=... (the compilation root
// is the Rails root, so the payload references images as
// /app/assets/images/...).
//
// Payload strings are inserted as text content: Typst never interprets them
// as markup, so the document is structurally immune to content injection.

#import "theme.typ": *

#let data = json(sys.inputs.data)

#show: letterhead.with(
  title: data.title,
  lang: data.lang,
  marianne: data.marianne,
  logo: data.logo,
  sender: data.sender,
)

#document-head(data.title, data.procedure, date: data.date)

#depot-description[#data.description]

#for section in data.sections {
  depot-section({
    heading(level: 2, section.title)
    key-value(..section.rows)
  })
}

#signature[#par[#data.signature]]
