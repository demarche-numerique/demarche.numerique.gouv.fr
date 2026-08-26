# frozen_string_literal: true

class TypesDeChamp::Datetime < TypeDeChamp
  def self.option_keys = [:date_in_past, :start_date, :end_date, :range_date]
  def self.column_type = :datetime

  def prefillable? = true
  def customizable? = true
  def birthdate? = false
  store_accessor :options, :date_in_past, :range_date, :start_date, :end_date
  boolean_options :date_in_past, :range_date

  def typed_champ_value(champ)
    I18n.l(Time.zone.parse(champ.value))
  end
end
