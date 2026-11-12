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
    all_revisions = revisions.to_a
    ProcedureRevision.preload_type_de_champs(all_revisions)

    all_revisions
      .flat_map { pieces_jointes(exclude_titre_identite: true, revision: it) }
      .sort_by { - _1.id }.uniq(&:stable_id)
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
    type_de_champs = public_only ? revision.public_flat_type_de_champs : revision.type_de_champs

    type_de_champs = type_de_champs.filter(&:piece_justificative?)

    # Exclude titre_identite (now piece_justificative with nature=titre_identite)
    if exclude_titre_identite
      type_de_champs = type_de_champs.reject(&:titre_identite?)
    end

    return type_de_champs if !wrap_with_parent

    # we want pj in the form of [[pj1], [pj2, repetition], [pj3, repetition]]
    type_de_champs.map { [it, it.enclosing_repetition].compact }
  end
end
