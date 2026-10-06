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

  validate :validate_repetition_min, on: :champ_completeness, if: :visible?
  validate :validate_repetition_max, if: :should_validate_in_current_context?

  private

  def validate_repetition_min
    return if !type_de_champ.limit_repetitions?
    return if type_de_champ.min_repetitions.blank?

    min = type_de_champ.min_repetitions.to_i
    errors.add(:value, :repetition_too_few, min:, libelle: type_de_champ.libelle) if row_ids.count < min
  end

  def validate_repetition_max
    return if !type_de_champ.limit_repetitions?
    return if type_de_champ.max_repetitions.blank?

    max = type_de_champ.max_repetitions.to_i
    return if row_ids.count <= max
    return if rows.none? { |row| row.flat_children.any? { it.value.present? } }

    errors.add(:value, :repetition_too_many, max:, libelle: type_de_champ.libelle)
  end
end
