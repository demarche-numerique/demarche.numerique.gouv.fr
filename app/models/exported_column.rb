# frozen_string_literal: true

class ExportedColumn
  attr_reader :column, :libelle

  def initialize(column:, libelle:)
    @column = column
    @libelle = libelle
  end

  def id = { id: column.id, libelle: }.to_json

  # Takes the dossier for dossier columns, the champ's ChampData (or nil when
  # the champ was never filled) for champ columns.
  def libelle_with_value(champ_or_dossier, format:)
    [libelle, ExportedColumnFormatter.format(column:, champ_or_dossier:, format:), spreadsheet_architect_type]
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
