# frozen_string_literal: true

class Champs::CheckboxChamp < Champs::BooleanChamp
  # A checkbox has no empty state: untouched, it displays unchecked, so a
  # condition on it reads « Non » rather than « pas de reponse ».
  def blank_for_condition? = false

  # Untouched, the row holds nil: unchecking posts 'false' through the hidden
  # field. value_updated_at, set on user writes only, covers a write normalized
  # back to nil. A prefilled value is real data, not implicit.
  def implicit_value? = value.nil? && self[:value_updated_at].nil?

  def legend_label?
    false
  end

  def self.options
    [[I18n.t('activerecord.attributes.type_de_champ.type_champs.checkbox_true'), true], [I18n.t('activerecord.attributes.type_de_champ.type_champs.checkbox_false'), false]]
  end

  def html_label?
    false
  end

  def single_checkbox?
    true
  end
end
