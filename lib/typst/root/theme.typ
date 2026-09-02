// Print theme for our PDF documents, laid out on the letterhead grid of the
// charte graphique de l'Etat (Marque de l'Etat, "Papeterie et print - papier
// en-tete" of the operateurs et entites servicielles chapter): A4 with 17mm
// margins, the bloc-marque top left, the logotype top right (never taller
// than the bloc-marque), the content zone 43.5mm below the bloc-marque, the
// sender block bottom left and the page number bottom right, everything in
// Marianne ragged left (Regular 11pt body, Bold 12pt subject, 8pt footer).
// Layout decisions live here; templates only assemble data into them.
//
// Compiled by TypstService with lib/typst/root as --root (templates, /images,
// /fonts) and --pdf-standard ua-1.

#let ink = black
#let bleu-france = rgb("000091")

// The charte's letterhead grid.
#let page-margin = 17mm
#let bloc-marque-offset = 4.25mm // below the top margin
#let bloc-marque-height = 20mm
#let content-offset = 43.5mm // content zone below the bloc-marque top
#let logotype-max-width = 53mm
#let footer-height = 12mm

// Image resolved by the caller. When no file is available the alt text is
// rendered in a placeholder frame, so the document still compiles and the
// information stays available.
#let logo-image(path: none, alt: "", height: auto, width: auto) = if path != none {
  image(path, alt: alt, height: height, width: width, fit: "contain")
} else {
  rect(stroke: 0.5pt + luma(120), inset: 2mm, height: height, text(size: 7pt, fill: luma(120))[#alt])
}

// The operator logotype: as tall as the bloc-marque, unless that would make
// it wider than its zone.
#let logotype(logo) = context {
  let tall = logo-image(path: logo.path, alt: logo.alt, height: bloc-marque-height)
  if logo.path != none and measure(tall).width > logotype-max-width {
    logo-image(path: logo.path, alt: logo.alt, width: logotype-max-width)
  } else {
    tall
  }
}

// First-page header: bloc-marque left, logotype right; an instance without a
// bloc-marque puts its logotype in the emitter slot on the left. The block
// spans the whole header zone so the content starts on the grid whatever the
// image heights.
#let letterhead-header(marianne: none, logo: none) = block(
  width: 100%,
  height: bloc-marque-offset + content-offset,
  above: 0mm,
  below: 0mm,
  inset: (top: bloc-marque-offset),
  grid(
    columns: (1fr, auto),
    align: (left + top, right + top),
    if marianne != none { logo-image(path: marianne.path, alt: marianne.alt, height: bloc-marque-height) } else { logotype(logo) },
    if marianne != none { logotype(logo) },
  ),
)

// Every page: sender lines bottom left, page number bottom right, both
// resting on the bottom margin.
#let letterhead-footer(sender) = block(width: 100%, height: footer-height, align(bottom, grid(
  columns: (1fr, auto),
  align: (left + bottom, right + bottom),
  {
    set text(size: 8pt)
    set par(spacing: 0pt)
    for line in sender { par(line) }
  },
  text(size: 8pt, context counter(page).display("1/1", both: true)),
)))

// Document shell.
#let letterhead(title: none, lang: "fr", marianne: none, logo: none, sender: (), doc) = {
  set document(title: title)
  set page(
    paper: "a4",
    margin: (x: page-margin, top: page-margin, bottom: page-margin + footer-height),
    footer: letterhead-footer(sender),
    footer-descent: 0pt,
  )
  set text(font: "Marianne", size: 11pt, lang: lang, fill: ink)
  set par(justify: false)
  show heading: set block(sticky: true)
  show heading.where(level: 2): set text(size: 12pt)
  show heading.where(level: 2): set block(above: 8mm, below: 3mm)
  letterhead-header(marianne: marianne, logo: logo)
  doc
}

// Head of a letter-like document, after the charte's press release: the
// document type in Marianne Light 12pt capitals, then the subject in Bold
// 12pt with the date at the right end of the same line.
#let document-head(kind, subject, date: none) = {
  block(below: 4mm, {
    show heading.where(level: 1): set text(size: 12pt, weight: "light")
    show heading.where(level: 1): it => upper(it)
    heading(level: 1, kind)
  })
  block(below: 8mm, grid(
    columns: (1fr, auto),
    column-gutter: 8mm,
    align: (left, right),
    text(size: 12pt, weight: "bold", subject),
    if date != none { text(size: 12pt, weight: "bold", date) },
  ))
}

// Attestation de depot

#let depot-description(body) = block(below: 8mm, body)

#let depot-section(body) = block(below: 6mm, body)

// Key/value list (HTML <dl>): a borderless two-column table keeps the
// pairing in the PDF tag tree.
#let key-value(..pairs) = table(
  columns: (45mm, 1fr),
  stroke: none,
  inset: (x: 0mm, y: 0.75mm),
  column-gutter: 5mm,
  ..pairs.pos().map(((term, desc)) => (strong(term), desc)).flatten(),
)

#let signature(body) = align(right, block(above: 14mm, inset: (right: 25mm), body))
