# frozen_string_literal: true

class TypesDeChamp::COJOTypeDeChamp < TypesDeChamp::TextTypeDeChamp
  def self.category = REFERENTIEL
  def self.icon = 'fr-icon-medal-line'
  def self.feature_flag = :cojo_type_de_champ

  def prefillable? = false
  def customizable? = false

  def typed_champ_value(champ)
    "#{champ.accreditation_number} – #{champ.accreditation_birthdate}"
  end

  def typed_champ_blank?(champ) = champ.accreditation_success != true
end
