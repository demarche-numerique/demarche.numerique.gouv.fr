# frozen_string_literal: true

class TypesDeChamp::DateTypeDeChamp < TypesDeChamp::TypeDeChampBase
  def champ_value(champ)
    DateFormatHelper.long(Time.zone.parse(champ.value))
  rescue ArgumentError
    champ.value.presence || "" # old dossiers can have not parseable dates
  end
end
