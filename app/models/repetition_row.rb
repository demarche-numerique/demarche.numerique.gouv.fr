# frozen_string_literal: true

class RepetitionRow < Hashie::Dash
  property :id
  property :index
  property :dossier
  property :type_de_champ

  # All the champs of the row, including champs nested in header sections.
  def flat_champs
    type_de_champ.flat_children.map { dossier.project_champ(it, row_id: id) }
  end

  # Entry points to navigate the row's champs as a tree: first-level champs and
  # top-level header sections. Navigate deeper with
  # Champs::HeaderSectionChamp#children.
  def champs
    type_de_champ.children.map { dossier.project_champ(it, row_id: id) }
  end

  def dossier_id
    dossier.id.to_s
  end

  def read_attribute_for_serialization(attribute)
    self[attribute]
  end

  def spreadsheet_columns(types_de_champ, export_template: nil, format:)
    [
      ['Dossier ID', :dossier_id],
      ['Ligne', :index],
    ] + dossier.champ_values_for_export(types_de_champ, row_id: id, export_template:, format:)
  end
end
