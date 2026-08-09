# frozen_string_literal: true

class ExportTemplate::ChampsComponent < ApplicationComponent
  attr_reader :export_template, :title

  def initialize(title, export_template, types_de_champ, revision:)
    @title = title
    @export_template = export_template
    @types_de_champ = types_de_champ
    @revision = revision
  end

  def historical_libelle(column)
    historical_exported_column = export_template.exported_columns.find { _1.column == column }
    if historical_exported_column
      historical_exported_column.libelle
    else
      column.label
    end
  end

  # Columns grouped under their top-level section: types de champ before the
  # first section come first, without a libelle; a section's group holds every
  # champ below it, sub-sections included. Repetition content stays behind its
  # repetition's grouped columns.
  def sections
    champs, headers = @types_de_champ.partition { !it.header_section? }

    [
      { libelle: nil, columns: columns_for(champs) },
      *headers.map do |header|
        content = header.flat_children.reject { it.header_section? || it.in_repetition? }
        { libelle: header.libelle, columns: columns_for(content) }
      end,
    ].filter { it[:columns].present? }
  end

  def component_prefix
    title.parameterize
  end

  private

  def columns_for(types_de_champ)
    types_de_champ.map { tdc_to_columns(it) }.reject(&:empty?)
  end

  def tdc_to_columns(type_de_champ)
    prefix = type_de_champ.repetition? ? "Bloc répétable" : nil
    type_de_champ.columns(prefix:).map do |column|
      ExportedColumn.new(column:,
                         libelle: historical_libelle(column))
    end
  end
end
