# frozen_string_literal: true

class ProcedureExportService::RepetitionMaxRows
  BATCH_SIZE = 10_000

  def initialize(dossiers:, stable_ids:)
    @dossiers = dossiers
    @stable_ids = stable_ids
  end

  def to_h
    return {} if @stable_ids.empty?

    @dossiers.reorder(nil).ids.each_slice(BATCH_SIZE).each_with_object({}) do |dossier_ids, max_rows|
      max_rows.merge!(max_rows_for(dossier_ids)) { |_stable_id, max, rows_count| [max, rows_count].max }
    end
  end

  private

  def max_rows_for(dossier_ids)
    ChampData
      .from(rows_count_per_dossier(dossier_ids), :rows_counts)
      .group('rows_counts.stable_id')
      .maximum('rows_counts.rows_count')
  end

  def rows_count_per_dossier(dossier_ids)
    ChampData
      .where(
        dossier_id: dossier_ids,
        stable_id: @stable_ids,
        stream: Dossier::MAIN_STREAM,
        type: Champs::RepetitionChamp.sti_name,
        discarded_at: nil
      )
      .where.not(row_id: nil)
      .group(:stable_id, :dossier_id)
      .select(:stable_id, 'COUNT(*) AS rows_count')
  end
end
