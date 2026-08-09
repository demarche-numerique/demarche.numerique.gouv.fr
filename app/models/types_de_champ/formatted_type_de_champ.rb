# frozen_string_literal: true

class TypesDeChamp::FormattedTypeDeChamp < TypesDeChamp::TypeDeChampBase
  def initialize(*args)
    super
    if @type_de_champ.options&.empty?
      @type_de_champ.options = { formatted_mode: 'simple', letters_accepted: true, numbers_accepted: true, special_characters_accepted: true }
    end
  end

  def filled_champ_value_for_export(champ, path = :value)
    Sanitizers::Xml.sanitize(champ_text_value(champ))
  end
end
