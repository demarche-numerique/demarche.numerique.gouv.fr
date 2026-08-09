# frozen_string_literal: true

class Champs::HeaderSectionChamp < ChampData
  def search_terms
    # The user cannot enter any information here so it doesn’t make much sense to search
  end

  def level
    type_de_champ.level
  end

  # Direct children of the section, as projected champs (sharing the section's
  # row_id when the section is inside a repetition).
  def children
    type_de_champ.children.map { dossier.project_champ(it, row_id:) }
  end

  # Every champ below the section in document order, as projected champs.
  # Direct content shares the section's row_id; a nested repetition expands
  # into its rows, each row's champs projected with the row's own row_id.
  def flat_children
    type_de_champ.children.flat_map do
      champ = dossier.project_champ(it, row_id:)
      if champ.repetition?
        [champ, *champ.rows.flat_map(&:flat_champs)]
      elsif champ.header_section?
        [champ, *champ.flat_children]
      else
        [champ]
      end
    end
  end
end
