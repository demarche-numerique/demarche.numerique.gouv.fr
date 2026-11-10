# frozen_string_literal: true

class ExportTemplate::ChampsComponent < ApplicationComponent
  attr_reader :export_template, :title

  def initialize(title, export_template, type_de_champs)
    @title = title
    @export_template = export_template
    @type_de_champs = type_de_champs
  end

  def historical_libelle(column)
    historical_exported_column = export_template.exported_columns.find { _1.column == column }
    if historical_exported_column
      historical_exported_column.libelle
    else
      column.label
    end
  end

  def sections
    @type_de_champs
      .reject { _1.header_section? && _1.header_section_level_value > 1 }
      .slice_before(&:header_section?)
      .filter_map do |(head, *rest)|
        libelle = head.libelle if head.header_section?
        columns = [head.header_section? ? nil : head, *rest].compact.map { tdc_to_columns(_1) }
        { libelle:, columns: } if columns.present?
      end
  end

  def component_prefix
    title.parameterize
  end

  private

  def tdc_to_columns(type_de_champ)
    prefix = type_de_champ.repetition? ? "Bloc répétable" : nil
    type_de_champ.columns(procedure_id: export_template.procedure.id, prefix:).map do |column|
      ExportedColumn.new(column:,
                         libelle: historical_libelle(column),
                         raw: export_template.exported_columns.find { _1.column == column }&.raw)
    end
  end
end
