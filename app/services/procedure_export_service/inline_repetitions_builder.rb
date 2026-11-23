# frozen_string_literal: true

class ProcedureExportService::InlineRepetitionsBuilder
  def initialize(procedure:, dossiers:, export_template:)
    @procedure = procedure
    @dossiers = dossiers
    @export_template = export_template
  end

  def enabled? = @export_template.present? && @export_template.inline_repetitions?

  def to_h
    return {} if !enabled?

    @to_h ||= begin
      max_rows = ProcedureExportService::RepetitionMaxRows.new(dossiers: @dossiers, stable_ids: repetition_columns.keys).to_h
      max_repetitions = max_repetitions_set_by_administrateur

      repetition_columns.to_h do |stable_id, children_columns|
        rows_count = [max_rows.fetch(stable_id, 0), max_repetitions.fetch(stable_id, 0)].max
        [stable_id, ProcedureExportService::InlineRepetition.new(max_rows: rows_count, columns_by_child: children_columns)]
      end
    end
  end

  private

  def max_repetitions_set_by_administrateur
    stable_ids = @procedure.repetition_type_de_champs_for_procedure_export
      .filter { it.max_repetitions? && repetition_columns.key?(it.stable_id) }
      .map(&:stable_id)

    return {} if stable_ids.empty?

    # the versions the effective revisions lay out: the draft may hold another
    laid_out_ids = ProcedureRevision
      .where(id: @procedure.effective_revision_ids)
      .pluck(:type_de_champ_tree)
      .flat_map(&:type_de_champ_ids)
      .to_set

    TypeDeChamp
      .where(procedure_id: @procedure.id, stable_id: stable_ids, type_champ: TypeDeChamp.type_champs.fetch(:repetition))
      .filter { laid_out_ids.include?(it.id) && it.max_repetitions? }
      .group_by(&:stable_id)
      .transform_values { |versions| versions.map { it.max_repetitions.to_i }.max }
  end

  def repetition_columns
    @repetition_columns ||= @procedure.repetition_type_de_champs_for_procedure_export
      .to_h { [it.stable_id, columns_by_child(it)] }
      .filter { |_, children_columns| children_columns.any? }
  end

  def columns_by_child(repetition)
    @procedure.repetition_children_for_procedure_export(repetition)
      .index_with { @export_template.columns_for_stable_id(it.stable_id) }
      .filter { |_, exported_columns| exported_columns.any? }
  end
end
