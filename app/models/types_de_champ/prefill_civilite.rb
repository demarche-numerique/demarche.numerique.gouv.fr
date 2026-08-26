# frozen_string_literal: true

class TypesDeChamp::PrefillCivilite < TypesDeChamp::Prefill
  NORMALIZE_MAP = {
    'm.' => Individual::GENDER_MALE,
    'm' => Individual::GENDER_MALE,
    'mr' => Individual::GENDER_MALE,
    'monsieur' => Individual::GENDER_MALE,
    'male' => Individual::GENDER_MALE,
    'homme' => Individual::GENDER_MALE,
    'mme' => Individual::GENDER_FEMALE,
    'madame' => Individual::GENDER_FEMALE,
    'mlle' => Individual::GENDER_FEMALE,
    'mademoiselle' => Individual::GENDER_FEMALE,
    'female' => Individual::GENDER_FEMALE,
    'femme' => Individual::GENDER_FEMALE,
  }.freeze

  private

  def screened_value(champ, value)
    return nil if !value.is_a?(String)

    NORMALIZE_MAP[value.strip.downcase]
  end
end
