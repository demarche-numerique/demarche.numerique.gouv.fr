# frozen_string_literal: true

# One row of a repetition champ: the row id, its 1-based position, and the
# champs projected on it (`flat_children`, built lazily).
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
end
