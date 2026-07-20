# frozen_string_literal: true

# Types de champ are navigable as a tree: header sections and repetitions have
# children, other types are leaves. Sections have no parent relationship in the
# database, so the tree is reconstructed by the revision from the ordered list
# of coordinates and header levels.
module TypeDeChampTreeConcern
  extend ActiveSupport::Concern

  # Direct children of a header section or repetition: its own types de champ
  # and the immediate subsections (but not their content).
  def children(revision) = revision.children_of(self)

  # Sections and repetitions above this type de champ, outermost first.
  def ancestors(revision) = revision.ancestors_of(self)

  # Every type de champ below, in document order, including nested section
  # headers, repetition row content and their own content.
  def flat_children(revision)
    children(revision).flat_map { [it, *it.flat_children(revision)] }
  end

  # The repetition this type de champ belongs to, nil outside a repetition.
  def repetition(revision)
    ancestors(revision).find(&:repetition?)
  end

  # The innermost section this type de champ belongs to, nil outside sections.
  def section(revision)
    ancestors(revision).reverse.find(&:header_section?)
  end

  # The direct parent of this type de champ in the tree, nil at the root.
  def parent(revision)
    ancestors(revision).last
  end

  # Nesting depth of a header section in the tree (1 for a top-level section).
  # Unlike the stored header_section_level, skipped levels are collapsed.
  def level(revision)
    ancestors(revision).count(&:header_section?) + 1
  end
end
