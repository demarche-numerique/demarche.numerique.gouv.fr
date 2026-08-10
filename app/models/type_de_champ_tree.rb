# frozen_string_literal: true

# Types de champ indexed as a tree: one recursive walk over the ordered root
# coordinates answers every tree navigation question — top-level entry points,
# direct children, ancestors, lookup by stable_id — without storing any tree
# state on the types de champ themselves (the same type de champ can belong to
# several revisions, so its tree position is a property of the revision).
#
# The tree emits typed wrappers (TypesDeChamp::TypeDeChampBase subclasses)
# bound to the revision the tree belongs to, so navigation from an emitted
# type de champ needs no revision argument. One wrapper per stable_id per
# tree: two lookups of the same type de champ return the same instance.
#
# Coordinates are consumed through a small duck type — #type_de_champ,
# #header_section?, #repetition? and #revision_types_de_champ (its children) —
# so a tree can later be built over synthetic coordinates, e.g. an aggregate
# of several revisions.
class TypeDeChampTree
  # The navigation surface a tree provider exposes, shared by ProcedureRevision
  # and AggregatedRevision so both answer the exact same contract. Includers
  # implement a (private) #tree returning their TypeDeChampTree.
  module Navigation
    # Entry points to navigate types de champ as a tree: first-level types de
    # champ and top-level header sections (their content collapses into the
    # header; navigate deeper with TypeDeChamp#children).
    def types_de_champ_public = tree.roots_public
    def types_de_champ_private = tree.roots_private

    def flat_types_de_champ_public = types_de_champ_public.flat_map { [it, *it.flat_children] }
    def flat_types_de_champ_private = types_de_champ_private.flat_map { [it, *it.flat_children] }
    def types_de_champ = flat_types_de_champ_public + flat_types_de_champ_private

    def root_types_de_champ_public = flat_types_de_champ_public.reject(&:in_repetition?)
    def root_types_de_champ_private = flat_types_de_champ_private.reject(&:in_repetition?)
    def root_types_de_champ = root_types_de_champ_public + root_types_de_champ_private

    # Repetitions can't nest, so every repetition in the tree is a root.
    def repetition_types_de_champ = root_types_de_champ.filter(&:repetition?)

    # Indexed lookup of a type de champ anywhere in the tree, repetition
    # content included. Returns nil when the stable_id is not part of the tree
    # or doesn't match the requested scope (:public or :private).
    def type_de_champ(stable_id, scope = nil)
      type_de_champ = tree.type_de_champ(stable_id)
      return if type_de_champ.nil?
      return if scope == :public && type_de_champ.private?
      return if scope == :private && type_de_champ.public?

      type_de_champ
    end

    delegate :ancestors_of, :children_of, to: :tree
  end

  # Top-level types de champ in order, a section's content collapsed into its
  # header. Navigate deeper with #children_of.
  attr_reader :roots_public, :roots_private

  def initialize(revision:, public_coordinates:, private_coordinates:)
    @revision = revision
    @wrappers = {}
    @ancestors = {}
    @children = {}
    @by_stable_id = {}
    @roots_public = walk(public_coordinates.to_a, [])
    @roots_private = walk(private_coordinates.to_a, [])
  end

  # Sections and repetitions above the given type de champ, outermost first.
  def ancestors_of(type_de_champ)
    @ancestors[key(type_de_champ)] || []
  end

  # Direct children of a header section or repetition: its own types de champ
  # and the immediate subsections (but not their content).
  def children_of(type_de_champ)
    @children[key(type_de_champ)] || []
  end

  def type_de_champ(stable_id)
    @by_stable_id[stable_id.to_i]
  end

  private

  # Returns the given coordinates' types de champ in order, a section's
  # content collapsed into its header; sections and repetitions recurse,
  # filling the indexes along the way. A section's content runs until the next
  # header of the same or a shallower level; a repetition's content is its
  # children coordinates.
  def walk(coordinates, ancestors)
    head, *tail = coordinates
    return [] if head.nil?

    # A handful of legacy rows frozen in old revisions predate the type_champ
    # presence validation; they have no behavior, so no tree exposes them.
    return walk(tail, ancestors) if head.type_de_champ.type_champ.blank?

    type_de_champ = wrap(head.type_de_champ)
    @ancestors[key(type_de_champ)] = ancestors
    @by_stable_id[type_de_champ.stable_id] = type_de_champ if type_de_champ.stable_id

    if head.header_section?
      content = tail.take_while { !same_or_shallower_level?(head, it) }
      @children[key(type_de_champ)] = walk(content, [*ancestors, type_de_champ])
      [type_de_champ, *walk(tail.drop(content.size), ancestors)]
    elsif head.repetition?
      @children[key(type_de_champ)] = walk(head.revision_types_de_champ, [*ancestors, type_de_champ])
      [type_de_champ, *walk(tail, ancestors)]
    else
      [type_de_champ, *walk(tail, ancestors)]
    end
  end

  def wrap(type_de_champ)
    @wrappers[key(type_de_champ)] ||= TypesDeChamp::TypeDeChampBase.build(type_de_champ, @revision)
  end

  def same_or_shallower_level?(header, coordinate)
    coordinate.header_section? &&
      coordinate.type_de_champ.header_section_level_value <= header.type_de_champ.header_section_level_value
  end

  # stable_id is nil until the type de champ is saved (e.g. when validating a
  # built procedure); fall back to the record itself so unsaved types de champ
  # don't all collide on the nil key.
  def key(type_de_champ)
    type_de_champ.stable_id || type_de_champ
  end
end
