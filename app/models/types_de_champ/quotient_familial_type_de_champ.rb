# frozen_string_literal: true

class TypesDeChamp::QuotientFamilialTypeDeChamp < TypesDeChamp::TypeDeChampBase
  def estimated_fill_duration(revision)
    FILL_DURATION_MEDIUM
  end

  def champ_blank?(champ)
    return true if champ.fetched? && champ.fc_data_approved?.nil?
    return false if champ.fc_data_correct?

    if !champ.fetched? || champ.fc_data_incorrect?
      champ.piece_justificative_file.blank?
    end
  end
end
