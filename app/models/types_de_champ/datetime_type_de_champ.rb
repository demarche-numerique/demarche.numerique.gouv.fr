# frozen_string_literal: true

class TypesDeChamp::DatetimeTypeDeChamp < TypesDeChamp::TypeDeChampBase
  def champ_value(champ)
    DateFormatHelper.default(Time.zone.parse(champ.value))
  end
end
