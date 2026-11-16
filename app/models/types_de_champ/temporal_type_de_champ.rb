# frozen_string_literal: true

class TypesDeChamp::TemporalTypeDeChamp < TypeDeChamp
  def self.icon = 'fr-icon-calendar-line'
  def self.option_keys = [:date_in_past, :start_date, :end_date, :range_date]
  def self.menu_value = TypeDeChamp::TEMPORAL_MENU_VALUE

  def prefillable? = true
  def customizable? = true

  store_accessor :options, :date_in_past, :range_date, :start_date, :end_date
  boolean_options :date_in_past, :range_date

  def temporal_type_champ
    type_champ
  end
end
