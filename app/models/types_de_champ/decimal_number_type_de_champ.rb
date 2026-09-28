# frozen_string_literal: true

class TypesDeChamp::DecimalNumberTypeDeChamp < TypeDeChamp
  def self.icon = 'fr-icon-hashtag'
  def self.option_keys = [:positive_number, :min_number, :max_number, :range_number]
  def self.column_type = :decimal
  def self.conditionable? = true

  def prefillable? = true
  def customizable? = true
  def condition_value_type = :number
  store_accessor :options, :positive_number, :min_number, :max_number, :range_number
  boolean_options :positive_number, :range_number

  def typed_champ_value_for_api(champ, version: 2)
    case version
    when 1
      champ_formatted_value(champ)
    else
      super
    end
  end

  # 0 when blank
  def legacy_export_columns(procedure_id:)
    [legacy_export_column(procedure_id:, label: libelle, columns: canonical_column(procedure_id:), type: :decimal) { it || 0 }]
  end

  private

  def champ_formatted_value(champ)
    champ.value&.to_f
  end
end
