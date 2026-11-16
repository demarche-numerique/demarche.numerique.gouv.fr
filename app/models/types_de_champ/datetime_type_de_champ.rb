# frozen_string_literal: true

class TypesDeChamp::DatetimeTypeDeChamp < TypesDeChamp::TemporalTypeDeChamp
  def self.column_type = :datetime
  def birthdate? = false

  def typed_champ_value(champ)
    I18n.l(Time.zone.parse(champ.value))
  end
end
