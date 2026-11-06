# frozen_string_literal: true

class ProcedureExportService::InlineRepetitionsBuilder
  def initialize(procedure:, dossiers:, export_template:)
    @procedure = procedure
    @dossiers = dossiers
    @export_template = export_template
  end

  def enabled? = @export_template.present?

  def type_de_champs
    @type_de_champs ||= if enabled?
      @procedure.all_revisions_type_de_champs.to_a
    else
      @procedure.type_de_champs_for_procedure_export.to_a
    end
  end

  def to_h
    return {} if !enabled?

    @to_h ||= begin
      max_rows = ProcedureExportService::RepetitionMaxRows.new(dossiers: @dossiers, stable_ids: repetition_columns.keys).to_h

      repetition_columns.to_h do |stable_id, children_columns|
        [stable_id, ProcedureExportService::InlineRepetition.new(max_rows: max_rows.fetch(stable_id, 0), columns_by_child: children_columns)]
      end
    end
  end

  private

  def repetition_columns
    @repetition_columns ||= type_de_champs
      .filter(&:repetition?)
      .to_h { [it.stable_id, columns_by_child(it)] }
      .filter { |_, children_columns| children_columns.any? }
  end

  def columns_by_child(repetition)
    @procedure.all_revisions_type_de_champs(parent: repetition)
      .index_with { @export_template.columns_for_stable_id(it.stable_id) }
      .filter { |_, exported_columns| exported_columns.any? }
  end
end
