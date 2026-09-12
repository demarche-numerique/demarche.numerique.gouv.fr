// Dossier PDF (the usager's and instructeur's copy of a submitted dossier).
// `render` receives the JSON payload built by Typst::DossierPayload, decoded by
// the entry document that TypstService feeds on stdin; images are referenced
// as /images/... (repository files) or /assets/... (files downloaded for the
// rendering) in the compilation root.
//
// Payload strings are inserted as text content, never interpreted as Typst
// markup. Champ blocks are a small discriminated union (type field); an
// unknown type panics, so payload and template cannot drift silently.

#import "theme.typ": *

#let render-champ(champ) = {
  if champ.type == "heading" {
    heading(level: champ.level, champ.text)
  } else if champ.type == "field" {
    champ-label(champ.label)
    if champ.blank { blank-value(champ.value) } else if champ.value != none { par(champ.value) }
    if champ.details.len() > 0 { detail-rows(..champ.details) }
  } else if champ.type == "files" {
    champ-label(champ.label)
    list(..champ.files)
  } else if champ.type == "explication" {
    champ-label(champ.label)
    if champ.text != none { rich-text(champ.text) }
  } else if champ.type == "carte" {
    champ-label(champ.label)
    // (the static map is a square-ish raster: cap its height rather than its width)
    if champ.map != none { illustration(champ.map, height: 70mm) }
    if champ.areas.len() > 0 {
      list(..champ.areas.map(area => {
        area.label
        if area.description != none { linebreak(); emph(area.description) }
      }))
    }
  } else if champ.type == "repetition" {
    champ-label(champ.label)
    for row in champ.rows {
      repetition-row(row.title, for child in row.champs { dossier-entry(sticky: child.type == "heading", render-champ(child)) })
    }
  } else {
    panic("unknown champ block type: " + champ.type)
  }
}

#let render-champs(section) = {
  heading(level: 2, section.title)
  for champ in section.champs {
    dossier-entry(sticky: champ.type == "heading", render-champ(champ))
  }
}

#let render(data) = {
  show: letterhead.with(
    title: data.title,
    lang: data.lang,
    marianne: data.marianne,
    logo: data.logo,
    sender: data.sender,
  )

  // Heading scale of the form sections, stepping down from the 12pt section
  // title to the 11pt body, each with room above it.
  show heading.where(level: 2): set block(above: 10mm, below: 4mm)
  show heading.where(level: 3): set text(size: 11pt)
  show heading.where(level: 3): set block(above: 7mm, below: 3mm)
  show heading.where(level: 4): set text(size: 11pt, style: "italic")
  show heading.where(level: 5): set text(size: 10pt)
  show heading.where(level: 6): set text(size: 10pt, style: "italic")
  show heading.where(level: 4).or(heading.where(level: 5)).or(heading.where(level: 6)): set block(above: 6mm, below: 3mm)

  document-head(data.title, data.procedure, date: data.date)

  if data.draft_warning != none { callout(data.draft_warning.title, data.draft_warning.text) }

  for section in data.sections {
    heading(level: 2, section.title)
    key-value(columns: (60mm, 1fr), ..section.rows)
  }

  render-champs(data.form)

  if data.annotations != none { render-champs(data.annotations) }

  if data.avis != none {
    heading(level: 2, data.avis.title)
    for avis in data.avis.items { avis-block(avis) }
  }

  if data.messages != none {
    heading(level: 2, data.messages.title)
    for message in data.messages.items { message-block(message) }
  }
}
