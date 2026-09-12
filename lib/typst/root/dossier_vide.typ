// Dossier vide (empty printable form). `render` receives the JSON payload
// built by DossierVidePayload, decoded by the entry document that
// TypstService feeds on stdin; images are referenced as /images/... in this
// compilation root.
//
// Payload strings are inserted as text content, never interpreted as Typst
// markup. Champ blocks are a small discriminated union (type field); an
// unknown type panics, so payload and template cannot drift silently.

#import "theme.typ": *

#let render-champ(champ) = {
  if champ.type == "heading" {
    // (a section without a title only carries its description)
    if champ.text != none { heading(level: champ.level, champ.text) }
    if champ.at("description", default: none) != none { rich-text(champ.description, style: "italic") }
  } else if champ.type == "explication" {
    vide-label(champ.libelle)
    condition-instruction(champ)
    if champ.at("text", default: none) != none { rich-text(champ.text) }
  } else if champ.type == "piece_justificative" {
    vide-label(champ.label)
    options-list((( label: champ.option ),))
    if champ.at("description", default: none) != none { rich-text(champ.description, style: "italic") }
  } else if champ.type == "checkboxes" {
    vide-label(champ.libelle)
    condition-instruction(champ)
    if champ.at("description", default: none) != none { rich-text(champ.description, style: "italic") }
    if champ.at("explanation", default: none) != none { block(above: 1mm, below: 1.5mm, text(style: "italic")[#champ.explanation]) }
    options-list(champ.options)
  } else if champ.type == "box" {
    vide-label(champ.libelle)
    condition-instruction(champ)
    if champ.at("description", default: none) != none { rich-text(champ.description, style: "italic") }
    if champ.at("explanation", default: none) != none { block(above: 1mm, below: 1.5mm, text(style: "italic")[#champ.explanation]) }
    fillable-box(champ.box)
  } else if champ.type == "establishment" {
    vide-label(champ.libelle)
    condition-instruction(champ)
    field-pair("SIRET")
    field-pair("Dénomination")
    field-pair("Forme juridique")
  } else if champ.type == "repetition" {
    vide-label(champ.libelle)
    condition-instruction(champ)
    for occurrence in champ.occurrences {
      block(inset: (left: 3mm), below: 5mm, {
        for child in occurrence { champ-block(conditional: child.conditional, sticky: child.type == "heading", render-champ(child)) }
      })
    }
  } else {
    panic("unknown champ block type: " + champ.type)
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

  // Heading scale of the paper form, stepping down from the charte's Bold 14pt
  // direction title to the 11pt body.
  show heading.where(level: 1): set text(size: 14pt)
  show heading.where(level: 3): set text(size: 11pt)
  show heading.where(level: 4): set text(size: 11pt, style: "italic")
  show heading.where(level: 5): set text(size: 10pt)

  // Spelled-out URLs stay clickable, underlined and in the Etat blue. The
  // final character class keeps trailing punctuation (the closing paren of a
  // "label (url)" spelled-out link, an end-of-sentence period...) out of the
  // link target; "]" is literal as the first class member.
  show regex("https?://\S+[^]\s.,;:!?»«')]"): it => link(it.text, text(fill: bleu-france, style: "normal", underline(it.text)))

  heading(level: 1, data.title)

  block(above: 4mm, below: 6mm, grid(
    columns: (45mm, 1fr),
    column-gutter: 4mm,
    strong[Organisme],
    [#data.organisation],
  ))

  heading(level: 2)[Identité du demandeur]

  for field in data.identity_fields { field-pair(field) }

  heading(level: 2)[Formulaire]

  if data.presentation != none { rich-text(data.presentation) }

  if data.mailing != none { block(below: 4mm, text(style: "italic")[#data.mailing]) }

  for champ in data.champs {
    champ-block(conditional: champ.conditional, sticky: champ.type == "heading", render-champ(champ))
  }

  if data.annexes.len() > 0 {
    pagebreak()
    heading(level: 2)[Annexes]
    for annex in data.annexes {
      block(below: 6mm, width: 100%, {
        heading(level: 3, annex.title)
        annex-options(annex.options)
      })
    }
  }
}
