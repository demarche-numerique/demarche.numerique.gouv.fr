// Print theme for the PDF HTML profile (config/pdf_profile.yml).
//
// Hand-written Typst counterpart of attestation.scss: the HTML -> Typst
// compiler (PdfProfile::TypstCompiler) maps profile classes onto these
// functions. Layout decisions live here, never in the compiler.
//
// Compile with: typst compile --pdf-standard ua-1 --font-path lib/prawn/fonts

#let ink = rgb("161616")

// Document shell: A4, Marianne, page counter in the footer.
#let conf(title: none, lang: "fr", doc) = {
  set document(title: title)
  set page(
    paper: "a4",
    margin: (x: 17mm, top: 17mm, bottom: 34mm),
    footer: align(center, text(size: 8pt)[
      #context counter(page).display("1 / 1", both: true)
    ]),
  )
  set text(font: "Marianne", size: 10pt, lang: lang, fill: ink)
  show heading.where(level: 2): set text(size: 12pt)
  show heading.where(level: 2): set block(above: 0mm, below: 3mm)
  doc
}

// Compiler-resolved image. When the source file is not available locally the
// alt text is rendered in a placeholder frame, so the document still compiles
// and the information stays available.
#let profile-image(path: none, alt: "", height: auto, width: auto) = if path != none {
  image(path, alt: alt, height: height, width: width)
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
