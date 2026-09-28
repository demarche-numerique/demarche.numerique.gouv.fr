# frozen_string_literal: true

class TypesDeChamp::DatetimeTypeDeChamp < TypeDeChamp
  def self.icon = 'fr-icon-time-line'
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

  # the stored ISO 8601 string, not a datetime cell
  def legacy_export_columns(procedure_id:)
    [legacy_export_column(procedure_id:, label: libelle, columns: canonical_column(procedure_id:)) { it&.iso8601 }]
  end
end
