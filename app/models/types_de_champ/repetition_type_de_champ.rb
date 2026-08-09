# frozen_string_literal: true

class TypesDeChamp::RepetitionTypeDeChamp < TypesDeChamp::TypeDeChampBase
  def filled_champ_value_for_tag(champ, path = :value)
    return nil if path != :value
    ChampPresentations::RepetitionPresentation.new(libelle, champ.dossier.project_rows_for(@type_de_champ))
  end

  def estimated_fill_duration
    estimated_rows_in_repetition = 2.5

    children = flat_children

    estimated_row_duration = children.map(&:estimated_fill_duration).sum
    estimated_children_read_duration = children.map(&:estimated_read_duration).sum

    # Count only once children read time for all rows
    estimated_row_duration * estimated_rows_in_repetition + estimated_children_read_duration
  end

  # We have to truncate the label here as spreadsheets have a (30 char) limit on length.
  def libelle_for_export
    str = "(#{stable_id}) #{libelle}"
    # /\*?[] are invalid Excel worksheet characters
    ActiveStorage::Filename.new(str.delete('[]*?')).sanitized
  end

  def canonical_column(procedure_id:, displayable: true, prefix: nil)
    nil
  end

  def columns(procedure_id:, displayable: true, prefix: nil)
    prefix = prefix.present? ? "(#{prefix} #{libelle})" : libelle

    # Columns cover dossiers on every revision, so ask the aggregated
    # revision's own tree, whatever tree this wrapper came from.
    Procedure.find(procedure_id).aggregated_revision.type_de_champ(stable_id)
      .flat_children
      .flat_map { it.columns(procedure_id:, displayable: false, prefix:) }
  end

  def champ_value_blank?(champ) = champ.dossier.repetition_row_ids(@type_de_champ).blank?
end
