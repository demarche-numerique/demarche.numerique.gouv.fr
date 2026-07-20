# frozen_string_literal: true

class TypesDeChamp::HeaderSectionTypeDeChamp < TypesDeChamp::TypeDeChampBase
  def tags_for_template = [].freeze

  # Direct children of the section: its own types de champ and the immediate subsections
  # (but not their content). Sections have no parent relationship in the database, so
  # children are reconstructed from the ordered list of siblings and header levels.
  def children(revision) = revision.children_of(@type_de_champ)

  def flat_children(revision) = revision.flat_children_of(@type_de_champ)
end
