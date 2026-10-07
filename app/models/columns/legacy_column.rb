# frozen_string_literal: true

# A column of the default tabular export (see LegacyExportTemplate) that keeps
# the cell formatting of the historical export where the catalogue column
# formats differently: it reads one or more catalogue columns and transforms
# their raw values ('on'/'off' from a boolean, 0 for a blank number, a date
# back to its stored string, "primaire;secondaire" from the two parts…). Its
# type drives ExportedColumnFormatter like any other column's.
#
# It only ever exists in memory: it is not part of Procedure#columns and can
# not be saved in an ExportTemplate.
class Columns::LegacyColumn < Column
  def initialize(procedure_id:, columns:, label:, type: :text, &transform)
    @columns = Array(columns)
    @transform = transform || -> (value) { value }
    base = @columns.first

    super(procedure_id:, table: base.table, column: base.column, label:, type:, displayable: false, filterable: false)
  end

  # A nil champ is a blank one (see Dossier#filled_champ): the transform gets
  # the base columns' nil and decides on the default.
  def value(champ_or_dossier)
    @transform.call(*@columns.map { it.value(champ_or_dossier) })
  end

  def champ_column? = @columns.first.champ_column?
  def dossier_column? = @columns.first.dossier_column?
  def stable_id = @columns.first.stable_id

  def column_id = "legacy/#{@columns.map(&:column_id).join('+')}/#{label}"
end
