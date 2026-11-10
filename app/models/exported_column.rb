# frozen_string_literal: true

class ExportedColumn
  attr_reader :column, :libelle, :raw

  def initialize(column:, libelle:, raw: false)
    @column = column
    @libelle = libelle
    @raw = raw
  end

  def id = { id: column.id, libelle:, raw: (true if raw) }.compact.to_json

  def libelle_with_value(champ_or_dossier, format:)
    [libelle, ExportedColumnFormatter.format(column:, champ_or_dossier:, format:, raw:), spreadsheet_architect_type]
  end

  def spreadsheet_architect_type
    case @column.type
    when :boolean
      :boolean
    when :decimal, :integer
      :float
    when :datetime
      :time
    when :date
      :date
    else
      :string
    end
  end
end
