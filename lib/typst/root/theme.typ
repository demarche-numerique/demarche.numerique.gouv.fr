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
#let rouge-marianne = rgb("E1000F")
#let ink-muted = luma(90)

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
#let illustration(asset, width: 100%, height: auto) = block(width: 100%, below: 3mm, align(center, asset-image(path: asset.path, alt: asset.alt, width: width, height: height)))

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
#let key-value(columns: (45mm, 1fr), ..pairs) = table(
  columns: columns,
  stroke: none,
  inset: (x: 0mm, y: 1.25mm),
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
#let champ-label(body) = block(sticky: true, below: 2mm, strong(body))

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
// A linked list keeps its two levels: primaries in bold, secondaries indented.
#let annex-options(options) = columns(2, gutter: 6mm, {
  set text(size: 8.5pt)
  set par(spacing: 1mm, leading: 0.5em)
  let hierarchical = options.any(option => option.at("secondary", default: false))
  for option in options {
    if option.at("secondary", default: false) {
      par(h(4mm) + option.label)
    } else if hierarchical {
      par(strong(option.label))
    } else {
      par(option.label)
    }
  }
})

// --------------------------------------------------------------------------
// Dossier (the usager's and instructeur's copy of a submitted dossier)

// Warning callout (a dossier of a procedure in test): a red rule and title.
#let callout(title, body) = block(
  width: 100%,
  below: 6mm,
  inset: (left: 4mm, y: 2mm),
  stroke: (left: 2pt + rouge-marianne),
  {
    set par(spacing: 1mm)
    par(strong(text(fill: rouge-marianne, title)))
    par(body)
  },
)

// Value the usager did not provide.
#let blank-value(body) = par(emph(text(fill: ink-muted, body)))

// Detail rows of a champ (address parts, etablissement data...), indented
// under its value.
#let detail-rows(..pairs) = block(above: 2.5mm, inset: (left: 6mm), {
  set text(size: 10pt)
  key-value(..pairs)
})

// One entry of the form: a champ with its label and value, or a section
// heading kept attached to the entry that follows it.
#let dossier-entry(sticky: false, body) = block(width: 100%, below: 6mm, sticky: sticky, body)

// One occurrence of a repetition block, shaded like the web view.
#let repetition-row(title, body) = block(
  width: 100%,
  below: 4mm,
  inset: 4mm,
  fill: rgb("f6f6f6"),
  {
    block(sticky: true, below: 3mm, strong(title))
    body
  },
)

// An avis: whom it was asked from, the question in muted type, the answer.
#let avis-block(avis) = block(width: 100%, below: 6mm, {
  set par(spacing: 1mm)
  block(sticky: true, below: 1.5mm, strong(avis.title))
  par(text(fill: ink-muted, avis.question))
  par(avis.answer)
  if avis.binary_question != none {
    block(above: 2mm, {
      par(text(fill: ink-muted, avis.binary_question))
      par(avis.binary_answer)
    })
  }
})

// A message of the messagerie: sender and date, then the body.
#let message-block(message) = block(width: 100%, below: 6mm, {
  set par(spacing: 1mm)
  block(sticky: true, below: 1.5mm, {
    strong(message.sender)
    h(2mm)
    text(size: 9pt, fill: ink-muted, message.date)
  })
  par(message.body)
})

// --------------------------------------------------------------------------
// Attestation (the decision letter an administration authors in the tiptap
// editor, laid out by Typst::Tiptap): the administration's own letterhead
// (its bloc-marque or logo, direction, footer) rather than the instance's,
// and the body's blocks as the editor shows them, at the historical 10pt.

#let attestation-text-size = 10pt

// The vertical rhythm of the historical (HTML) rendering: a text line of room
// between blocks (1em margins), list items 0.25rem apart, the rows of a
// repetition 5mm apart. HTML measured those gaps between line boxes where
// typst measures from a baseline to the next cap height, hence the extra
// half text size.
#let attestation-gap(html-gap) = html-gap + 0.5 * attestation-text-size
#let attestation-block-gap = attestation-gap(attestation-text-size)
#let attestation-item-gap = attestation-gap(3pt)
#let attestation-row-gap = attestation-gap(5mm)

// An image no larger than the given box, keeping its proportions (a logo or a
// signature uploaded by the administration).
#let bounded-image(asset, width: none, height: auto) = context {
  let tall = asset-image(path: asset.path, alt: asset.alt, height: height)
  if asset.path != none and width != none and measure(tall).width > width {
    asset-image(path: asset.path, alt: asset.alt, width: width)
  } else {
    tall
  }
}

// The official bloc-marque of the issuing administration: the Marianne, its
// name, the devise (the charte's bloc-marque, the name lines authored).
#let bloc-marque(intitule) = {
  set par(spacing: 0pt, leading: 0.3em)
  image("/images/centered_marianne.svg", alt: "République française", height: 4.25mm)
  v(1mm)
  block(text(size: 12pt, weight: "bold", intitule.join(linebreak())))
  v(1mm)
  image("/images/liberte2.svg", alt: "Liberté Égalité Fraternité", height: 8.5mm)
}

// First-page head: the bloc-marque (official layout) or the administration's
// logo on the left; the co-emitter logo and the direction lines on the right.
#let attestation-header(official: true, intitule: (), logo: none, direction: ()) = block(width: 100%, below: 14mm, grid(
  columns: (auto, 1fr, auto),
  align: (left + top, center, right + top),
  if official { bloc-marque(intitule) } else if logo != none { bounded-image(logo, width: 50mm, height: 50mm) },
  [],
  grid(
    columns: 2,
    column-gutter: 5mm,
    align: (right + top, right + top),
    if official and logo != none { bounded-image(logo, height: 28mm) },
    if direction.len() > 0 {
      block(inset: (top: 5.25mm), {
        set par(spacing: 0pt, leading: 0.35em)
        set align(right)
        text(size: 12pt, weight: "bold", direction.join(linebreak()))
      })
    },
  ),
))

// Every page: the authored footer lines bottom left in small light type, the
// page number bottom right, both resting on the bottom margin.
#let attestation-footer(lines) = block(width: 100%, height: footer-height, align(bottom, grid(
  columns: (1fr, auto),
  column-gutter: 8mm,
  align: (left + bottom, right + bottom),
  {
    set text(size: 7pt, weight: "light")
    if lines.len() > 0 { par(lines.join(linebreak())) }
  },
  text(size: 8pt, context counter(page).display("1 / 1", both: true)),
)))

// Document shell.
#let attestation-page(title: none, footer: (), doc) = {
  set document(title: title)
  set page(
    paper: "a4",
    margin: (x: page-margin, top: page-margin, bottom: page-margin + footer-height),
    footer: attestation-footer(footer),
    footer-descent: 0pt,
  )
  set text(font: "Marianne", size: attestation-text-size, lang: "fr", fill: ink)
  set par(justify: false)
  show heading: set block(sticky: true)
  doc
}

#let aligned(alignment, body) = {
  if alignment == "center" { align(center, body) }
  else if alignment == "right" { align(right, body) }
  else if alignment == "justify" { set par(justify: true); body }
  else { body }
}

// The tiptap header: one column per authored column, the first flush left,
// the last flush right, the blocks laid out inside each as authored (render
// is the block renderer, which this header is itself a block of), its
// paragraphs the lines of an address.
#let attestation-columns(columns, render) = block(below: 14mm, grid(
  columns: columns.map(_ => auto).intersperse(1fr),
  align: (left + top, center, right + top),
  ..columns.map(blocks => box({
    set par(spacing: 0.65em)
    blocks.map(render).join()
  })).intersperse([]),
))

// A heading: its outline level structures the PDF, the style the admin gave
// it in the editor sets its look (the title and section headings in 12pt,
// sub-headings at text size), the title with the letterhead's room around it.
#let attestation-heading(node) = block(
  sticky: true,
  above: if node.style == "title" { attestation-gap(14mm) } else { attestation-block-gap },
  below: if node.style == "title" { attestation-gap(12.6mm) } else { attestation-block-gap },
  heading(level: node.level, text(size: if node.style == "subsection" { attestation-text-size } else { 12pt }, rich-inlines(node.content))),
)

#let attestation-block(node) = {
  if node.type == "header" { attestation-columns(node.columns, attestation-block) }
  else if node.type == "heading" { aligned(node.align, attestation-heading(node)) }
  else if node.type == "paragraph" { aligned(node.align, par(rich-inlines(node.content))) }
  else if node.type == "list" {
    // The blocks of an item (a nested list) sit as close as the items; the
    // rows of a repetition keep their room.
    let items = node.items.map(item => {
      set par(spacing: attestation-item-gap)
      item.map(attestation-block).join()
    })
    let repetition = node.items.any(item => item.any(block => block.type == "details"))
    let spacing = if repetition { attestation-row-gap } else { attestation-item-gap }
    if node.ordered { enum(tight: false, spacing: spacing, start: node.start, ..items) } else { list(tight: false, spacing: spacing, ..items) }
  }
  else if node.type == "details" {
    // (a repetition row: its term/value pairs, the first level with the item
    // number)
    table(
      columns: (auto, 1fr),
      stroke: none,
      inset: 0pt,
      row-gutter: attestation-item-gap,
      column-gutter: 10mm,
      ..node.rows.flatten(),
    )
  }
  else if node.type == "pagebreak" { pagebreak(weak: true) }
  else { panic("unknown attestation block type: " + node.type) }
}

// The body: blocks a text line apart, lists indented as on the web.
#let attestation-body(blocks) = {
  set par(spacing: attestation-block-gap)
  set list(indent: 10mm)
  set enum(indent: 8.5mm)
  for node in blocks { attestation-block(node) }
}
