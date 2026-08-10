# frozen_string_literal: true

# Streams a procedure's dossiers into an xlsx file with bounded memory: the
# Dossiers sheet is written row by row while the secondary sheets
# (Etablissements, Avis, Repetitions) are buffered as primitive values and
# flushed once Dossiers is closed (xlsxtream cannot interleave sheets).
#
# Kept separate from ProcedureExportService so the multi-format service stays a
# thin dispatcher; the same streaming shape can later back a CSV export.
class ProcedureExportService::XlsxExport
  def initialize(procedure:, dossiers:, export_template:)
    @procedure = procedure
    @dossiers = dossiers
    @export_template = export_template

    @current_dossier_id = nil
  end

  # Résout une cellule `[libellé, valeur, type]` (le type n'est présent que via
  # export_template). Reproduit le typage de SpreadsheetArchitect : un booléen
  # ne devient une cellule native (t="b") que si la colonne est explicitement
  # typée `:boolean` ; sinon il est stringifié — comme l'export caxlsx précédent,
  # où `get_type` ne typait jamais les booléens auto-détectés.
  def self.cell_value(instance, value, type)
    value = instance.send(value) if value.is_a?(Symbol)

    if (value == true || value == false) && type != :boolean
      value.to_s
    else
      value
    end
  end

  def write_to(io)
    buffers = SecondarySheetBuffers.new(procedure: @procedure)

    ProcedureExportService::XlsxStreamer.new(io).open do |writer|
      stream_dossiers_sheet(writer, buffers)
      flush_etablissements_sheet(writer, buffers)
      flush_avis_sheet(writer, buffers)
      flush_repetition_sheets(writer, buffers)
    end
  rescue StandardError
    Sentry.set_extras(
      xlsx_streamer: {
        procedure: @procedure.id,
        export_template: @export_template&.id,
        current_dossier: @current_dossier_id,
      }
    )
    raise
  end

  private

  def stream_dossiers_sheet(writer, buffers)
    sheet = nil
    headers = nil

    DossierPreloader.new(@dossiers.ordered_for_export)
      .in_batches(includes: DossierPreloader::SHEET_EXPORT_INCLUDES) do |batch|
      rows = batch.map do |dossier|
        @current_dossier_id = dossier.id
        columns = dossier.spreadsheet_columns_xlsx(types_de_champ:, export_template: @export_template)
        # En-têtes dérivés du 1er dossier streamé : mêmes `columns` que ses
        # valeurs, donc cohérence libellé ↔ valeur garantie par construction.
        headers ||= columns.map(&:first)

        buffers.collect_for_dossier(dossier, @export_template)
        columns.map { |(_libelle, value, type)| self.class.cell_value(dossier, value, type) }
      end

      # xlsxtream écrit <cols> avant toute ligne : on ouvre la feuille à la
      # réception du 1er batch, dimensionnée sur le contenu réel de ce batch
      # (échantillon). Les batches suivants sont streamés sans rebufferiser.
      if sheet.nil?
        widths = ProcedureExportService::XlsxStreamer.column_widths(headers, rows)
        sheet = writer.open_sheet('Dossiers', headers:, widths:)
      end
      rows.each { |cells| sheet.add_row(cells) }
    end

    if sheet
      writer.close_sheet(sheet)
    else
      # Aucun dossier : on ouvre quand même une feuille (en-têtes seuls, inconnus).
      writer.write_sheet('Dossiers', headers: []) { nil }
    end

    @current_dossier_id = nil
  end

  def flush_etablissements_sheet(writer, buffers)
    write_buffered_sheet(writer, 'Etablissements', buffers.etablissements_headers, buffers.etablissements_rows)
  end

  def flush_avis_sheet(writer, buffers)
    write_buffered_sheet(writer, 'Avis', buffers.avis_headers, buffers.avis_rows)
  end

  def flush_repetition_sheets(writer, buffers)
    buffers.repetition_sheets.each do |(libelle, headers, rows)|
      write_buffered_sheet(writer, libelle, headers, rows)
    end
  end

  # Feuilles bufferisées : toutes les lignes sont en mémoire, on dimensionne donc
  # les colonnes exactement sur leur contenu (parité avec l'autofit caxlsx).
  def write_buffered_sheet(writer, name, headers, rows)
    widths = ProcedureExportService::XlsxStreamer.column_widths(headers, rows)
    writer.write_sheet(name, headers:, widths:) do |sheet|
      rows.each { |values| sheet.add_row(values) }
    end
  end

  def types_de_champ
    @types_de_champ ||= @procedure.types_de_champ_for_procedure_export.to_a
  end

  # Accumulates rows for the Etablissements, Avis and Repetition sheets while we
  # stream the main Dossiers sheet.
  #
  # Values from `spreadsheet_columns` may be raw values or Symbols (method names
  # to call on the source instance, mimicking SpreadsheetArchitect behavior).
  # We resolve them at collection time so the buffer only holds primitive values.
  class SecondarySheetBuffers
    ETABLISSEMENT_HEADERS = Etablissement.new.spreadsheet_columns.map(&:first).freeze
    AVIS_HEADERS = Avis.new.spreadsheet_columns.map(&:first).freeze

    def initialize(procedure:)
      @procedure = procedure
      @etablissements_buffer = []
      @avis_buffer = []
      @repetition_buffers = {} # stable_id => { libelle:, headers:, rows: [] }
    end

    def collect_for_dossier(dossier, export_template)
      collect_etablissements(dossier)
      collect_avis(dossier)
      collect_repetitions(dossier, export_template)
    end

    def etablissements_headers = ETABLISSEMENT_HEADERS
    def etablissements_rows = @etablissements_buffer
    def avis_headers = AVIS_HEADERS
    def avis_rows = @avis_buffer

    # Ordonné par position canonique des TdC (parité avec l'export caxlsx), et non
    # par ordre d'insertion dans @repetition_buffers : celui-ci dépend de l'ordre
    # de découverte au fil des dossiers et peut diverger de l'ordre des colonnes.
    def repetition_sheets
      repetition_tdcs.filter_map do |tdc|
        entry = @repetition_buffers[tdc.stable_id]
        next if entry.nil? || entry[:rows].empty?
        [entry[:libelle], entry[:headers], entry[:rows]]
      end
    end

    private

    def collect_etablissements(dossier)
      dossier.filled_champs.filter(&:siret?).filter_map(&:etablissement).each do |etablissement|
        @etablissements_buffer << resolve_values(etablissement, etablissement.spreadsheet_columns)
      end

      if dossier.etablissement
        @etablissements_buffer << resolve_values(dossier.etablissement, dossier.etablissement.spreadsheet_columns)
      end
    end

    def collect_avis(dossier)
      dossier.avis.each do |avis|
        @avis_buffer << resolve_values(avis, avis.spreadsheet_columns)
      end
    end

    def collect_repetitions(dossier, export_template)
      repetition_tdcs.each do |tdc|
        rows = dossier.project_rows_for(tdc)
        next if rows.empty?

        children_tdcs = repetition_children_tdcs[tdc.stable_id]
        entry = @repetition_buffers[tdc.stable_id] ||= {
          libelle: tdc.libelle_for_export,
          headers: nil,
          rows: [],
        }

        rows.each do |row|
          columns = row.spreadsheet_columns(children_tdcs, export_template:, format: :xlsx)
          entry[:headers] ||= columns.map(&:first)
          entry[:rows] << resolve_values(row, columns)
        end
      end
    end

    def repetition_tdcs
      @repetition_tdcs ||= @procedure.aggregated_revision.repetition_types_de_champ
    end

    def repetition_children_tdcs
      @repetition_children_tdcs ||= repetition_tdcs.to_h do |tdc|
        [tdc.stable_id, tdc.flat_children.filter(&:fillable?)]
      end
    end

    def resolve_values(instance, columns)
      columns.map do |(_libelle, value, type)|
        ProcedureExportService::XlsxExport.cell_value(instance, value, type)
      end
    end
  end
end
