# frozen_string_literal: true

class Champs::HeaderSectionChamp < ChampData
  include ChampContainerConcern

  def search_terms
    # The user cannot enter any information here so it doesn’t make much sense to search
  end

  # the champs of a header section within a repetition are those of its row
  def children
    type_de_champ.children.map { dossier.project_champ(it, row_id:) }
  end
end
