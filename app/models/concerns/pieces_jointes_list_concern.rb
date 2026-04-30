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

  def exportables_pieces_jointes_for_all_versions
    pieces_jointes(
      exclude_titre_identite: true,
      revision: revisions
    ).sort_by { - _1.id }.uniq(&:stable_id)
  end

  def outdated_exportables_pieces_jointes
    exportables_pieces_jointes_for_all_versions - exportables_pieces_jointes
  end

  private

  def pieces_jointes(
    exclude_titre_identite: false,
    public_only: false,
    wrap_with_parent: false,
    revision: active_revision
  )
    coordinates = ProcedureRevisionTypeDeChamp.where(revision:).includes(:type_de_champ, :parent)

    coordinates = coordinates.public_only if public_only

    coordinates = coordinates.where(types_de_champ: { type_champ: 'piece_justificative' })

    # Exclude titre_identite (now piece_justificative with nature=titre_identite)
    coordinates = coordinates.to_a
    if exclude_titre_identite
      coordinates = coordinates.reject { _1.type_de_champ.titre_identite? }
    end

    return coordinates.map(&:type_de_champ) if !wrap_with_parent

    # we want pj in the form of [[pj1], [pj2, repetition], [pj3, repetition]]
    coordinates
      .map { |c| c.child? ? [c, c.parent] : [c] }
      .map { |a| a.map(&:type_de_champ) }
  end
end
