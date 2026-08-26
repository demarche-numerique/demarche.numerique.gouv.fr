# frozen_string_literal: true

class TypesDeChamp::Repetition < TypeDeChamp
  def self.category = STRUCTURE
  def self.option_keys = [:limit_repetitions, :min_repetitions, :max_repetitions]
  def self.allowed_in_repetition? = false

  def prefillable? = true
  def has_label? = false
  store_accessor :options, :limit_repetitions, :min_repetitions, :max_repetitions
  boolean_options :limit_repetitions

  before_validation :reset_limits_if_disabled

  def typed_champ_value_for_tag(champ, path = :value)
    return nil if path != :value
    ChampPresentations::RepetitionPresentation.new(libelle, champ.dossier.project_rows_for(self))
  end

  def estimated_fill_duration(revision)
    estimated_rows_in_repetition = 2.5

    children = revision.children_of(self)

    estimated_row_duration = children.map { _1.estimated_fill_duration(revision) }.sum
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

    Procedure.find(procedure_id)
      .all_revisions_type_de_champs(parent: self)
      .flat_map { it.columns(procedure_id:, displayable: false, prefix:) }
  end

  def typed_champ_blank?(champ) = champ.dossier.repetition_row_ids(self).blank?

  private

  def reset_limits_if_disabled
    return if limit_repetitions?

    self.min_repetitions = nil
    self.max_repetitions = nil
  end
end
