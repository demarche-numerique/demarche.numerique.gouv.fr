# frozen_string_literal: true

# Merge policy: the newest revision is the backbone; a type de champ absent from
# newer revisions is kept in the container (section, repetition or scope root)
# it last belonged to, appended after that container's current content; the
# newest version of each type de champ wins.
#
# The merge is computed from the revisions' coordinate trees and projected to
# nested plain ids, cached for published procedures — published revisions are
# immutable, so the cache key turns over on publication. The aggregated tree is
# then rebuilt per instance over freshly loaded types de champ and unsaved
# coordinates: nothing loaded by the merge (or by another instance) is exposed.
module ProcedureAggregatedTypesDeChampConcern
  extend ActiveSupport::Concern

  def aggregated_public_type_de_champs
    @aggregated_public_type_de_champs ||= build_aggregated_coordinates(:public).map(&:type_de_champ)
  end

  def aggregated_private_type_de_champs
    @aggregated_private_type_de_champs ||= build_aggregated_coordinates(:private).map(&:type_de_champ)
  end

  # flattened aggregated types de champ without repetition children, mirroring
  # ProcedureRevision#root_types_de_champ_public/private
  def aggregated_root_types_de_champ_public
    aggregated_public_type_de_champs.flat_map { [it] + it.flat_children }.filter { !it.in_repetition? }
  end

  def aggregated_root_types_de_champ_private
    aggregated_private_type_de_champs.flat_map { [it] + it.flat_children }.filter { !it.in_repetition? }
  end

  def reset_aggregated_types_de_champ_cache
    @aggregated_revisions = nil
    @merged_structures = nil
    @aggregated_types_de_champ_by_id = nil
    @aggregated_public_type_de_champs = nil
    @aggregated_private_type_de_champs = nil
  end

  private

  # { public: [{ id:, children: }], private: [...] } — pure data.
  def merged_structures
    @merged_structures ||= if brouillon?
      compute_merged_structures
    else
      Rails.cache.fetch(['aggregated_types_de_champ', id, published_revision_id], expires_in: 1.month) do
        compute_merged_structures
      end
    end
  end

  def compute_merged_structures
    revisions = aggregated_revisions
    {
      public: structure(merge(revisions.map(&:public_coordinates))),
      private: structure(merge(revisions.map(&:private_coordinates))),
    }
  end

  def structure(coordinates)
    coordinates.map { { id: it.type_de_champ.id, children: structure(it.children) } }
  end

  def aggregated_revisions
    @aggregated_revisions ||= begin
      scope = brouillon? ? revisions.where(id: draft_revision_id) : revisions.where.not(id: draft_revision_id)

      scope.reorder(created_at: :desc).to_a.tap { ProcedureRevisionPreloader.new(_1).all if _1.many? }
    end
  end

  # Fold the coordinate trees newest first: the first one is the backbone, each
  # older one only brings the coordinates it alone still holds.
  def merge(coordinate_trees)
    placed = {}

    coordinate_trees.reduce([]) { |merged, tree| merge_tree(merged, tree, placed) }
  end

  def merge_tree(merged, coordinates, placed)
    coordinates.reduce(merged) do |container, coordinate|
      placed_coordinate = placed[coordinate.stable_id]

      if placed_coordinate.nil?
        placed[coordinate.stable_id] = coordinate
        coordinate.children = merge_tree([], coordinate.children, placed)

        container + [coordinate]
      else
        placed_coordinate.children = merge_tree(placed_coordinate.children, coordinate.children, placed)

        container
      end
    end
  end

  # The merged structure rebuilt as a tree of unsaved coordinates over fresh
  # types de champ.
  def build_aggregated_coordinates(scope)
    merged_structures.fetch(scope).map { build_coordinate(it) }
  end

  def build_coordinate(node)
    coordinate = ProcedureRevisionTypeDeChamp.new(type_de_champ: aggregated_types_de_champ_by_id.fetch(node[:id]))
    coordinate.type_de_champ.coordinate = coordinate
    coordinate.children = node[:children].map { build_coordinate(it) }

    coordinate
  end

  def aggregated_types_de_champ_by_id
    @aggregated_types_de_champ_by_id ||= TypeDeChamp
      .where(id: merged_structures.values.flat_map { structure_ids(it) })
      .index_by(&:id)
  end

  def structure_ids(structure)
    structure.flat_map { [it[:id], *structure_ids(it[:children])] }
  end
end
