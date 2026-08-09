# frozen_string_literal: true

class TypesDeChamp::TextareaTypeDeChamp < TypesDeChamp::TextTypeDeChamp
  def estimated_fill_duration(revision)
    FILL_DURATION_MEDIUM
  end

  def filled_champ_value_for_export(champ, path = :value)
    Sanitizers::Xml.sanitize(champ_text_value(champ))
  end
end
