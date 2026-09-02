// Print theme for our PDF documents, laid out on the letterhead grid of the
// charte graphique de l'Etat (Marque de l'Etat, "Papeterie et print - papier
// en-tete" of the operateurs et entites servicielles chapter): A4 with 17mm
// margins, the bloc-marque top left, the logotype top right (never taller
// than the bloc-marque), the content zone 43.5mm below the bloc-marque, the
// sender block bottom left and the page number bottom right, everything in
// Marianne ragged left (Regular 11pt body, Bold 12pt subject, 8pt footer).
// Layout decisions live here; templates only assemble data into them.
//
// References (Marque de l'Etat, Service d'information du Gouvernement):
// - the charte graphique de l'Etat, the complete PDF (SIG, June 2021):
//   chapter "Papeterie et print" of the "Operateurs et entites servicielles"
//   part specifies the A4 letterhead grid used here (page 115), the
//   ministries' part (page 52) the letterhead with a direction zone and the
//   press release head; mirrored at
//   https://www.culture.gouv.fr/Media/medias-creation-rapide/charte_graphique_de_letat.pdf
// - the same content online (info.gouv.fr blocks non-browser clients):
//   https://www.info.gouv.fr/marque-de-letat/le-systeme-graphique
//   https://www.info.gouv.fr/marque-de-letat/le-bloc-marque
//   https://www.info.gouv.fr/marque-de-letat/la-typographie (Marianne and
//   Spectral downloads; Marianne is reserved to the State)
//   https://www.info.gouv.fr/marque-de-letat/les-couleurs
//   https://www.info.gouv.fr/marque-de-letat/operateurs-et-entites-servicielles
// - the DSFR print fundamentals, same typography and colours:
//   https://www.systeme-de-design.gouv.fr/elements-d-interface/fondamentaux-de-l-identite-de-l-etat/
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

// Image resolved by the caller (a repo file or a TypstService asset). When no
// file is available the alt text is rendered in a placeholder frame, so the
// document still compiles and the information stays available.
#let asset-image(path: none, alt: "", height: auto, width: auto) = if path != none {
  image(path, alt: alt, height: height, width: width, fit: "contain")
} else {
  rect(stroke: 0.5pt + luma(120), inset: 2mm, height: height, text(size: 7pt, fill: luma(120))[#alt])
}

// The operator logotype: as tall as the bloc-marque, unless that would make
// it wider than its zone.
#let logotype(logo) = context {
  let tall = asset-image(path: logo.path, alt: logo.alt, height: bloc-marque-height)
  if logo.path != none and measure(tall).width > logotype-max-width {
    asset-image(path: logo.path, alt: logo.alt, width: logotype-max-width)
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
    if marianne != none { asset-image(path: marianne.path, alt: marianne.alt, height: bloc-marque-height) } else { logotype(logo) },
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

// Illustration downloaded for the rendering (TypstService assets, a
// { path, alt } descriptor), centred on the text column: the alt text enters
// the PDF/UA tag tree, and a file that could not be resolved leaves the alt
// text in a placeholder frame, like the logos.
#let illustration(asset, width: 100%) = block(width: 100%, below: 3mm, align(center, asset-image(path: asset.path, alt: asset.alt, width: width)))

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

// --------------------------------------------------------------------------
// Dossier vide (empty printable form)

// Authored Markdown, as the block/inline tree built by Typst::RichText from
// the same rendering as the web form. Payload strings stay text content;
// only the tree's node types drive the markup.
#let rich-inlines(nodes) = nodes.map(node => {
  if node.type == "text" { node.text }
  else if node.type == "linebreak" { linebreak() }
  else if node.type == "strong" { strong(rich-inlines(node.content)) }
  else if node.type == "emph" { emph(rich-inlines(node.content)) }
  else if node.type == "underline" { underline(rich-inlines(node.content)) }
  else if node.type == "link" {
    // On paper the URL is the information: spelled out after its label (the
    // template's URL show rule makes the spelled-out copy clickable too).
    link(node.href, text(fill: bleu-france, style: "normal", underline(rich-inlines(node.content))))
    if node.spell != none { " (" + node.spell + ")" }
  }
  else { panic("unknown rich text inline type: " + node.type) }
}).join()

#let rich-text(blocks, style: "normal") = {
  set text(style: style)
  set par(spacing: 1.5mm)
  for node in blocks {
    if node.type == "paragraph" { par(rich-inlines(node.content)) }
    else if node.type == "list" {
      let items = node.items.map(rich-inlines)
      if node.ordered { enum(start: node.start, ..items) } else { list(..items) }
    }
    else { panic("unknown rich text block type: " + node.type) }
  }
}

// Empty field to fill in by hand.
#let fillable-box(kind) = rect(
  width: 100%,
  height: if kind == "line" { 6mm } else { 22mm },
  stroke: 1pt + ink,
)

// Label / fillable line pair (identity fields, establishment).
#let field-pair(label) = block(below: 2mm, grid(
  columns: (45mm, 1fr),
  column-gutter: 4mm,
  strong(label),
  fillable-box("line"),
))

// Champ label, kept attached to what follows it.
#let vide-label(body) = block(sticky: true, below: 1.5mm, strong(body))

#let condition-instruction(champ) = if champ.at("condition", default: none) != none {
  block(sticky: true, above: 1mm, below: 1.5mm, text(style: "italic")[#champ.condition])
}

// A decorative checkbox followed by the meaning-bearing label.
#let checkbox-option(label, secondary: false) = {
  if secondary { h(6mm) }
  box(baseline: 15%, rect(width: 3mm, height: 3mm, stroke: 1pt + ink))
  h(2mm)
  label
}

#let options-list(options) = block({
  set par(spacing: 1mm)
  for option in options {
    par(checkbox-option(option.label, secondary: option.at("secondary", default: false)))
  }
})

// One champ block; conditional champs are shaded like the web form. A
// section heading block sticks to the champ that follows it: the heading's
// own stickiness does not reach past the block wrapping it.
#let champ-block(conditional: false, sticky: false, body) = block(
  width: 100%,
  below: 7mm,
  sticky: sticky,
  inset: if conditional { 3mm } else { 0mm },
  fill: if conditional { rgb("f6f6f6") } else { none },
  body,
)

// Annex reference list: two columns of small type, one option per line.
#let annex-options(options) = columns(2, gutter: 6mm, {
  set text(size: 8.5pt)
  set par(spacing: 1mm, leading: 0.5em)
  for option in options { par[#option] }
})
