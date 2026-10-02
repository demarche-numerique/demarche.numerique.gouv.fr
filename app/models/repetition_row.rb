# frozen_string_literal: true

# One row of a repetition champ: the row id, its 1-based position, and the
# champs projected on it (`flat_children`, built lazily so that export code,
# which only needs the id, never pays for the projection).
class RepetitionRow
  attr_reader :id, :index, :dossier, :type_de_champ

  def initialize(id:, index:, dossier:, type_de_champ:, children_type_de_champs:)
    @id = id
    @index = index
    @dossier = dossier
    @type_de_champ = type_de_champ
    @children_type_de_champs = children_type_de_champs
  end

  def flat_children
    @flat_children ||= @children_type_de_champs.map { dossier.project_champ(it, row_id: id) }
  end

  def spreadsheet_columns(type_de_champs, export_template:, format:)
    [
      ['Dossier ID', dossier.id.to_s],
      ['Ligne', :index],
    ] + dossier.champ_values_for_export(type_de_champs, row_id: id, export_template:, format:)
  end
end
