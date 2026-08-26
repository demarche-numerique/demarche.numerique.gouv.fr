# frozen_string_literal: true

class TypesDeChamp::Text < TypeDeChamp
  def prefillable? = true
  def customizable? = true

  def typed_champ_value_for_export(champ, path = :value)
    Sanitizers::Xml.sanitize(champ_text_value(champ))
  end
end
