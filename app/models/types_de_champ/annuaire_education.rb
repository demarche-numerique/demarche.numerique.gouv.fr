# frozen_string_literal: true

class TypesDeChamp::AnnuaireEducation < TypesDeChamp::Text
  def self.category = REFERENTIEL_EXTERNE

  def prefillable? = false

  def estimated_fill_duration(revision)
    FILL_DURATION_MEDIUM
  end
end
