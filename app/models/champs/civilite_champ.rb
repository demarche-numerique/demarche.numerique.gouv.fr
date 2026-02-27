# frozen_string_literal: true

class Champs::CiviliteChamp < Champ
  validates :value, inclusion: ["M.", "Mme"], allow_nil: true, allow_blank: false, if: :validate_champ_value?

  def legend_label?
    true
  end

  def html_label?
    false
  end

  def self.options
    [[Individual::GENDER_FEMALE, Individual::GENDER_FEMALE], [Individual::GENDER_MALE, Individual::GENDER_MALE]]
  end

  def female_input_id
    "#{input_id}-female"
  end

  def male_input_id
    "#{input_id}-male"
  end

  def focusable_input_id(attribute = :value)
    female_input_id
  end
end
