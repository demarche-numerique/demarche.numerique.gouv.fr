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
    rows.last&.first&.focusable_input_id(attribute)
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

  validate :validate_repetition_limits, if: :should_validate_in_current_context?

  private

  def validate_repetition_limits
    return if !type_de_champ.limit_repetitions?
    # Only skip validation when no rows have been filled AND no minimum is required.
    # When a minimum is configured, always validate so that submitting with 0 rows is caught.
    return if type_de_champ.min_repetitions.blank? && rows.none? { |row| row.any? { _1.value.present? } }

    count = row_ids.count
    min = type_de_champ.min_repetitions.to_i
    max = type_de_champ.max_repetitions.to_i

    if type_de_champ.min_repetitions.present? && count < min
      errors.add(:value, :repetition_too_few, min: min, libelle: type_de_champ.libelle)
    end

    if type_de_champ.max_repetitions.present? && count > max
      errors.add(:value, :repetition_too_many, max: max, libelle: type_de_champ.libelle)
    end
  end

  class Row < Hashie::Dash
    property :index
    property :row_id
    property :dossier

    def dossier_id
      dossier.id.to_s
    end

    def read_attribute_for_serialization(attribute)
      self[attribute]
    end

    def spreadsheet_columns(types_de_champ, export_template: nil, format:)
      [
        ['Dossier ID', :dossier_id],
        ['Ligne', :index],
      ] + dossier.champ_values_for_export(types_de_champ, row_id:, export_template:, format:)
    end
  end
end
