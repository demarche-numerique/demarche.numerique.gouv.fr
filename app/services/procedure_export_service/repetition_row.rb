# frozen_string_literal: true

# A line of a repetition sheet: a row id and its 1-based position, read off the
# champ data, without projecting the champs of the row.
class ProcedureExportService::RepetitionRow < Data.define(:dossier, :id, :index)
  def self.for(dossier, type_de_champ)
    dossier.repetition_row_ids(type_de_champ).map.with_index(1) { |id, index| new(dossier:, id:, index:) }
  end

  def spreadsheet_columns(type_de_champs, export_template: nil, format:)
    [
      ['Dossier ID', dossier.id.to_s],
      ['Ligne', :index],
    ] + dossier.champ_values_for_export(type_de_champs, row_id: id, export_template:, format:)
  end
end
