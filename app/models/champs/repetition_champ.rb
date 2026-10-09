# frozen_string_literal: true

class Champs::RepetitionChamp < ChampData
  delegate :libelle_for_export, to: :type_de_champ

  def row_libelle
    children_types = dossier.revision.children_of(type_de_champ)
    if children_types.size == 1
      children_types.first.libelle
    else
      type_de_champ.libelle
    end
  end

  def rows
    dossier.project_rows_for(type_de_champ)
  end

  def row_ids
    dossier.repetition_row_ids(type_de_champ)
  end

  def add_row(updated_by:)
    dossier.repetition_add_row(type_de_champ, updated_by:)
  end

  def remove_row(row_id, updated_by:)
    dossier.repetition_remove_row(type_de_champ, row_id, updated_by:)
  end

  def focusable_input_id(attribute = :value)
    rows.last&.flat_children&.first&.focusable_input_id(attribute)
  end

  def discarded?
    discarded_at.present?
  end

  def discard!
    touch(:discarded_at)
  end

  def search_terms
    # The user cannot enter any information here so it doesn’t make much sense to search
  end

  def max_reached?
    return false if !type_de_champ.limit_repetitions?
    return false if type_de_champ.max_repetitions.blank?
    row_ids.count >= type_de_champ.max_repetitions.to_i
  end

  def min_repetitions?
    type_de_champ.limit_repetitions? && type_de_champ.min_repetitions.present?
  end

  def min_repetitions_reached?
    min_repetitions? && rows.count { filled_row?(it) } >= type_de_champ.min_repetitions.to_i
  end

  def too_many_rows?
    return false if !type_de_champ.limit_repetitions? || type_de_champ.max_repetitions.blank?

    row_ids.count > type_de_champ.max_repetitions.to_i && rows.any? { row_with_value?(it) }
  end

  validate :validate_repetition_min, on: :champ_completeness, if: :visible?
  validate :validate_repetition_max, if: :should_validate_in_current_context?

  private

  def row_with_value?(row)
    row.flat_children.compact_blank.any?(&:visible?)
  end

  def filled_row?(row)
    row_with_value?(row) && row.flat_children.none? { it.required? && it.mandatory_blank? }
  end

  def validate_repetition_min
    return if !min_repetitions? || min_repetitions_reached?

    errors.add(:value, :repetition_too_few, min: type_de_champ.min_repetitions.to_i, libelle: type_de_champ.libelle)
  end

  def validate_repetition_max
    return if !too_many_rows?

    errors.add(:value, :repetition_too_many, max: type_de_champ.max_repetitions.to_i, libelle: type_de_champ.libelle)
  end
end
