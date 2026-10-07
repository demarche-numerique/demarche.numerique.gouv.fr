# frozen_string_literal: true

module DossierExportConcern
  extend ActiveSupport::Concern

  def spreadsheet_columns_csv(type_de_champs:, export_template:)
    spreadsheet_columns(type_de_champs:, export_template:, format: :csv)
  end

  def spreadsheet_columns_xlsx(type_de_champs:, export_template:)
    spreadsheet_columns(type_de_champs:, export_template:, format: :xlsx)
  end

  def spreadsheet_columns_ods(type_de_champs:, export_template:)
    spreadsheet_columns(type_de_champs:, export_template:, format: :ods)
  end

  # One [libelle, value, type] cell per column the template exports for each
  # type de champ, in the order of the types de champ. A blank champ is nil.
  def champ_values_for_export(type_de_champs, row_id: nil, export_template:, format:)
    type_de_champs.flat_map do |type_de_champ|
      champ = filled_champ(type_de_champ, row_id:, with_discarded: true)
      export_template
        .columns_for_stable_id(type_de_champ.stable_id)
        .map { |exported_column| exported_column.libelle_with_value(champ, format:) }
    end
  end

  def spreadsheet_columns(type_de_champs:, export_template:, format:)
    Sentry.set_tags(dossier: id)
    dossier_values_for_export(export_template:, format:) + champ_values_for_export(type_de_champs, export_template:, format:)
  end

  private

  def dossier_values_for_export(export_template:, format:)
    export_template.dossier_exported_columns.map { _1.libelle_with_value(self, format:) }
  end
end
