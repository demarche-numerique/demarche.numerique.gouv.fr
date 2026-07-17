# frozen_string_literal: true

class Champs::HeaderSectionChamp < ChampData
  def search_terms
    # The user cannot enter any information here so it doesn’t make much sense to search
  end

  def level
    type_de_champ.level(dossier.revision)
  end

  # Direct children of the section, as projected champs (sharing the section's
  # row_id when the section is inside a repetition).
  def children
    type_de_champ.children(dossier.revision).map { dossier.project_champ(it, row_id:) }
  end

  # Every champ below the section in document order, as projected champs; a
  # nested repetition is a boundary (included, its rows' content excluded).
  def flat_children
    type_de_champ.flat_children(dossier.revision).map { dossier.project_champ(it, row_id:) }
  end
end
