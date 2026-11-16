# frozen_string_literal: true

module PiecesJointesListConcern
  extend ActiveSupport::Concern

  def public_wrapped_partionned_pjs
    pieces_jointes(public_only: true, wrap_with_parent: true)
      .partition { |(pj, _)| pj.condition.nil? }
  end

  def exportables_pieces_jointes
    pieces_jointes(exclude_titre_identite: true)
  end

  # The stable ids come from the aggregated tree and the draft's, their
  # versions from the procedure: a piece jointe turned into another type is
  # still one for the dossiers of the revisions before.
  def exportables_pieces_jointes_for_all_versions
    stable_ids = [aggregated_type_de_champ_tree, draft_revision.type_de_champ_tree].flat_map(&:nodes).map(&:stable_id).uniq

    type_de_champs
      .where(stable_id: stable_ids, type_champ: TypeDeChamp.type_champs.fetch(:piece_justificative))
      .reject(&:titre_identite?)
      .sort_by { -it.id }
      .uniq(&:stable_id)
  end

  def outdated_exportables_pieces_jointes
    # by stable id: the draft may hold a newer version of a piece jointe still published
    stable_ids = exportables_pieces_jointes.to_set(&:stable_id)

    exportables_pieces_jointes_for_all_versions.reject { stable_ids.member?(it.stable_id) }
  end

  private

  # Read from the tree of the active revision, without laying the types de
  # champ out: only the pieces jointes and the repetitions are loaded.
  def pieces_jointes(exclude_titre_identite: false, public_only: false, wrap_with_parent: false)
    tree = active_revision.type_de_champ_tree
    nodes_with_ancestors = public_only ? tree.public_nodes_with_ancestors : tree.nodes_with_ancestors

    type_de_champs_by_id = TypeDeChamp
      .where(id: nodes_with_ancestors.map { |node, _| node.type_de_champ_id })
      .where(type_champ: [TypeDeChamp.type_champs.fetch(:piece_justificative), TypeDeChamp.type_champs.fetch(:repetition)])
      .index_by(&:id)

    nodes_with_ancestors.filter_map do |node, ancestors|
      type_de_champ = type_de_champs_by_id[node.type_de_champ_id]

      next if !type_de_champ&.piece_justificative?
      # Exclude titre_identite (now piece_justificative with nature=titre_identite)
      next if exclude_titre_identite && type_de_champ.titre_identite?
      next type_de_champ if !wrap_with_parent

      # we want pj in the form of [[pj1], [pj2, repetition], [pj3, repetition]]
      [type_de_champ, ancestors.filter_map { type_de_champs_by_id[it.type_de_champ_id] }.find(&:repetition?)].compact
    end
  end
end
