# frozen_string_literal: true

# Aggregated view of a procedure's types de champ across every revision a
# dossier may still be using: the published history, or the draft alone on a
# never-published procedure. It exposes the same tree API as ProcedureRevision,
# so the same navigation works against either provider —
# tdc.section(aggregated_revision) as well as tdc.section(revision) — which is
# what filters, exports and the export template picker need: they operate on
# dossiers spanning several revisions.
#
# Merge policy (the spec holds the authoritative cases):
# - the newest revision a type de champ appears in provides its version;
# - the newest revision's layout is the backbone;
# - a type de champ absent from the newest revision keeps the container
#   (section, repetition or scope root) it last belonged to, appended after
#   that container's current content; a removed container is itself appended,
#   with its removed content.
#
# The merge is computed from the revisions' trees (coordinates batch-loaded in
# one query) and cached as plain ids for published procedures — published
# revisions are immutable, so the cache only turns over on publication. Types
# de champ are reloaded fresh and the tree is rebuilt per instance: no record
# or tree state ever enters the cache.
class AggregatedRevision
  # Duck-typed coordinate for TypeDeChampTree, emitted by the merge.
  Coordinate = Data.define(:type_de_champ, :children) do
    def header_section? = type_de_champ.header_section?
    def repetition? = type_de_champ.repetition?
    def revision_types_de_champ = children
  end

  def initialize(procedure)
    @procedure = procedure
  end

  # Entry points to navigate types de champ as a tree; same contract as
  # ProcedureRevision.
  def types_de_champ_public = tree.roots_public
  def types_de_champ_private = tree.roots_private

  def flat_types_de_champ_public = types_de_champ_public.flat_map { [it, *it.flat_children(self)] }
  def flat_types_de_champ_private = types_de_champ_private.flat_map { [it, *it.flat_children(self)] }
  def types_de_champ = flat_types_de_champ_public + flat_types_de_champ_private

  def root_types_de_champ_public = flat_types_de_champ_public.reject { it.in_repetition?(self) }
  def root_types_de_champ_private = flat_types_de_champ_private.reject { it.in_repetition?(self) }
  def root_types_de_champ = root_types_de_champ_public + root_types_de_champ_private

  def type_de_champ(stable_id, scope = nil)
    type_de_champ = tree.type_de_champ(stable_id)
    return if type_de_champ.nil?
    return if scope == :public && type_de_champ.private?
    return if scope == :private && type_de_champ.public?

    type_de_champ
  end

  delegate :ancestors_of, :children_of, to: :tree

  private

  def tree
    @tree ||= begin
      members, latest_ids = merged
      types_de_champ_by_id = TypeDeChamp.where(id: latest_ids.values).index_by(&:id)
      @members = members
      @latest_version = latest_ids.transform_values { types_de_champ_by_id.fetch(it) }

      TypeDeChampTree.new(
        public_coordinates: coordinates_for(members.fetch(:public, [])),
        private_coordinates: coordinates_for(members.fetch(:private, []))
      )
    end
  end

  # The merge as plain data: {container => ordered stable_ids} and
  # {stable_id => type de champ id}.
  def merged
    if @procedure.brouillon?
      compute_merged
    else
      cache_key = ['AggregatedRevision', @procedure.id, @procedure.published_revision_id]
      Rails.cache.fetch(cache_key, expires_in: 1.month) { compute_merged }
    end
  end

  # Containers are :public, :private or a section/repetition stable_id. Each
  # type de champ is placed exactly once — walking revisions newest first, in
  # the newest container it belonged to, after the members already placed
  # there.
  def compute_merged
    members = Hash.new { |hash, key| hash[key] = [] }
    latest_ids = {}
    placed = Set.new

    revisions.each do |revision|
      place = lambda do |container, types_de_champ|
        types_de_champ.each do |type_de_champ|
          stable_id = type_de_champ.stable_id
          latest_ids[stable_id] ||= type_de_champ.id
          members[container] << stable_id if placed.add?(stable_id)
          if type_de_champ.header_section? || type_de_champ.repetition?
            place.call(stable_id, revision.children_of(type_de_champ))
          end
        end
      end
      place.call(:public, revision.types_de_champ_public)
      place.call(:private, revision.types_de_champ_private)
    end

    members.default_proc = nil
    [members, latest_ids]
  end

  # Newest first: the first revision a stable_id appears in provides its
  # version and its place. Coordinates are batch-loaded in a single query.
  def revisions
    @revisions ||= if @procedure.brouillon?
      [@procedure.draft_revision]
    else
      (@procedure.revisions.to_a - [@procedure.draft_revision])
        .sort_by(&:created_at).reverse
        .tap { ProcedureRevisionPreloader.new(it).all if it.many? }
    end
  end

  # Synthetic coordinates in document order: a section's content inlined after
  # its header, a repetition's content on its own coordinate.
  def coordinates_for(stable_ids)
    stable_ids.flat_map do |stable_id|
      type_de_champ = @latest_version.fetch(stable_id)
      if type_de_champ.repetition?
        [Coordinate.new(type_de_champ:, children: coordinates_for(@members.fetch(stable_id, [])))]
      elsif type_de_champ.header_section?
        [Coordinate.new(type_de_champ:, children: []), *coordinates_for(@members.fetch(stable_id, []))]
      else
        [Coordinate.new(type_de_champ:, children: [])]
      end
    end
  end
end
