# frozen_string_literal: true

class TypesDeChamp::AnnuaireEducationTypeDeChamp < TypesDeChamp::TextTypeDeChamp
  def self.category = IDENTIFICATION
  def self.icon = 'fr-icon-school-line'

  def prefillable? = false

  def estimated_fill_duration(revision)
    FILL_DURATION_MEDIUM
  end
end
