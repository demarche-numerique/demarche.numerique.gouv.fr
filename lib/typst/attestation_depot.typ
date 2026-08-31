// Attestation de depot, rendered from a JSON payload written by TypstService
// to a tempfile whose path arrives as --input data=... (the compilation root
// is the Rails root, so the payload references images as
// /app/assets/images/...).
//
// Payload strings are inserted as text content: Typst never interprets them
// as markup, so the document is structurally immune to content injection.

#import "theme.typ": *

#let data = json(sys.inputs.data)

#show: conf.with(title: data.title, lang: data.lang)

#first-header(
  [
    #if data.marianne != none [
      #bloc-marque[#profile-image(path: data.marianne.path, alt: data.marianne.alt, height: 20mm)]
    ]
    #logo-site[#profile-image(path: data.logo.path, alt: data.logo.alt, height: 15mm, width: 30mm)]
  ],
  [
    #direction-block[
      #if data.direction_label != none [#direction-label[#data.direction_label]]
      #direction-site[#data.direction_site]
    ]
  ],
)

#depot-title[#data.title]

#depot-procedure[#data.procedure]

#depot-description[#data.description]

#for section in data.sections {
  depot-section({
    heading(level: 2, section.title)
    key-value(..section.rows)
  })
}

#signature[
  #for line in data.signature [#par[#line]]
]
