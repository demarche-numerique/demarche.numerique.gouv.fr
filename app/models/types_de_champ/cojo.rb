# frozen_string_literal: true

class TypesDeChamp::COJO < TypesDeChamp::Text
  def self.category = REFERENTIEL_EXTERNE
  def self.feature_flag = :cojo_type_de_champ

  def prefillable? = false
  def customizable? = false

  def typed_champ_value(champ)
    "#{champ.accreditation_number} – #{champ.accreditation_birthdate}"
  end

  def typed_champ_blank?(champ) = champ.accreditation_success != true
end
