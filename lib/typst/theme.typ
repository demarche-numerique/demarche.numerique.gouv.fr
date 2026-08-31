// Print theme for our PDF documents: the attestation stylesheet
// (attestation.scss) rewritten as Typst functions. Layout decisions live
// here; templates (attestation_depot.typ) only assemble data into them.
//
// Compile with: typst compile --pdf-standard ua-1 --font-path lib/prawn/fonts

#let ink = rgb("161616")

// Document shell: A4, Marianne, page counter in the footer.
#let conf(title: none, lang: "fr", margin-bottom: 34mm, doc) = {
  set document(title: title)
  set page(
    paper: "a4",
    margin: (x: 17mm, top: 17mm, bottom: margin-bottom),
    footer: align(center, text(size: 8pt)[
      #context counter(page).display("1 / 1", both: true)
    ]),
  )
  set text(font: "Marianne", size: 10pt, lang: lang, fill: ink)
  show heading.where(level: 2): set text(size: 12pt)
  show heading.where(level: 2): set block(above: 0mm, below: 3mm)
  doc
}

// Image resolved by the caller. When no file is available the alt text is
// rendered in a placeholder frame, so the document still compiles and the
// information stays available.
#let profile-image(path: none, alt: "", height: auto, width: auto) = if path != none {
  image(path, alt: alt, height: height, width: width, fit: "contain")
} else {
  rect(stroke: 0.5pt + luma(120), inset: 2mm, height: height, text(size: 7pt, fill: luma(120))[#alt])
}

// Two-column document header: marque block left, direction block right.
#let first-header(left-content, right-content) = grid(
  columns: (1fr, auto),
  align: (left, right),
  left-content,
  right-content,
)

#let bloc-marque(body) = box(inset: (right: 5mm), body)

#let logo-site(body) = box(inset: (left: 2mm), body)

#let direction-block(body) = align(right, body)

#let direction-label(body) = par(text(size: 8pt, body))

#let direction-site(body) = par(text(size: 10pt, weight: "bold", body))

// Attestation de depot
#let depot-title(body) = block(above: 10mm, below: 5mm, align(center, {
  show heading: set text(size: 16pt)
  heading(level: 1, body)
}))

#let depot-procedure(body) = align(center, block(below: 12mm, text(size: 12pt, weight: "bold", body)))

#let depot-description(body) = block(below: 10mm, body)

#let depot-section(body) = block(below: 8mm, body)

// Key/value list (HTML <dl>): a borderless two-column table keeps the
// pairing in the PDF tag tree.
#let key-value(..pairs) = table(
  columns: (40mm, 1fr),
  stroke: none,
  inset: (x: 0mm, y: 0.75mm),
  column-gutter: 5mm,
  ..pairs.pos().map(((term, desc)) => (strong(term), desc)).flatten(),
)

#let signature(body) = align(right, block(above: 14mm, inset: (right: 25mm), body))

// --------------------------------------------------------------------------
// Dossier vide (empty printable form) - counterpart of dossier_vide_pdf.scss

#let ds-blue = rgb("000091")

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
    link(node.href, text(fill: ds-blue, style: "normal", underline(rich-inlines(node.content))))
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
