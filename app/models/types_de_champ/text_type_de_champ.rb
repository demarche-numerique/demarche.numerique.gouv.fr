# frozen_string_literal: true

class TypesDeChamp::TextTypeDeChamp < TypeDeChamp
  def self.icon = 'fr-icon-text'
  def prefillable? = true
  def customizable? = true

  def typed_champ_value_for_export(champ, path = :value)
    Sanitizers::Xml.sanitize(champ_text_value(champ))
  end
end
