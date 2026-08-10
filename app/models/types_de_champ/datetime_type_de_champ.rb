# frozen_string_literal: true

class TypesDeChamp::DatetimeTypeDeChamp < TypesDeChamp::TypeDeChampBase
  def filled_champ_value(champ)
    I18n.l(Time.zone.parse(champ.value))
  end
end
