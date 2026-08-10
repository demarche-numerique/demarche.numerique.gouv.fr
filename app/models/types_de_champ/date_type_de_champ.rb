# frozen_string_literal: true

class TypesDeChamp::DateTypeDeChamp < TypesDeChamp::TypeDeChampBase
  def filled_champ_value(champ)
    I18n.l(Time.zone.parse(champ.value).to_date, format: :long)
  rescue ArgumentError
    champ.value.presence || "" # old dossiers can have not parseable dates
  end
end
