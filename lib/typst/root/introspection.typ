// Helpers for `typst eval --in <template>` queries (TypstService.query):
// specs introspect the laid-out document (headings, links, lists, tables...)
// instead of parsing the PDF. Not imported by the templates themselves.

// Plain text of a content tree, the way a reader sees it: spaces and line
// breaks kept, locatable elements unwrapped from their styled/tag wrappers.
#let plain(c) = {
  if type(c) == str { return c }
  // (by name: `space` has no exported function to compare against)
  let kind = repr(c.func())
  if kind == "text" { c.text }
  else if kind == "space" { " " }
  else if kind == "linebreak" { "\n" }
  else if c.has("child") { plain(c.child) }
  else if c.has("children") { c.children.map(plain).join("") }
  else if c.has("body") { plain(c.body) }
  else { "" }
}

// Headings as (level, text) pairs, in document order.
#let headings() = query(heading).map(h => (level: h.level, text: plain(h.body)))

// Links as (dest, text) pairs, in document order.
#let links() = query(link).map(l => (dest: l.dest, text: plain(l.body)))

// Bulleted lists as arrays of item texts.
#let lists() = query(list).map(l => l.children.map(plain))

// Numbered lists as (start, items).
#let enums() = query(enum).map(e => (start: e.fields().at("start", default: 1), items: e.children.map(plain)))

// Tables as arrays of cell texts.
#let tables() = query(table).map(t => t.children.map(plain))

// Paragraph texts, in document order.
#let paragraphs() = query(par).map(plain)

// Images as their alt texts, in document order.
#let images() = query(image).map(i => (alt: i.alt))
