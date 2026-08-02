# frozen_string_literal: true

# Merge policy: the newest revision is the backbone; a type de champ absent from
# newer revisions is kept in the container (section, repetition or scope root)
# it last belonged to, appended after that container's current content; the
# newest version of each type de champ wins.
module ProcedureAggregatedTypesDeChampConcern
  extend ActiveSupport::Concern

  def aggregated_public_type_de_champs
    @aggregated_public_type_de_champs ||= merged_public_coordinates.each(&:apply_tree_to_tdc).map(&:type_de_champ)
  end

  def aggregated_private_type_de_champs
    @aggregated_private_type_de_champs ||= merged_private_coordinates.each(&:apply_tree_to_tdc).map(&:type_de_champ)
  end

  def reset_aggregated_types_de_champ_cache
    @aggregated_revisions = nil
    @aggregated_public_type_de_champs = nil
    @aggregated_private_type_de_champs = nil
  end

  private

  def merged_public_coordinates = aggregated_revisions.map(&:public_coordinates).then { merge(it) }
  def merged_private_coordinates = aggregated_revisions.map(&:private_coordinates).then { merge(it) }

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
end
