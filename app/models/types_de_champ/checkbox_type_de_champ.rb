# frozen_string_literal: true

class TypesDeChamp::CheckboxTypeDeChamp < TypeDeChamp
  def self.category = CHOICE
  def self.icon = 'fr-icon-checkbox-blank-line'
  def self.column_type = :boolean
  def self.conditionable? = true

  def prefillable? = true
  def options_for_select = Champs::CheckboxChamp.options
  def condition_value_type = :boolean

  def typed_champ_value(champ)
    champ_value_true?(champ) ? 'Oui' : 'Non'
  end

  def typed_champ_value_for_api(champ, version: 2)
    case version
    when 2
      champ_value_true?(champ).to_s
    else
      super
    end
  end

  def champ_default_value
    'Non'
  end

  def champ_default_api_value(version = 2)
    case version
    when 2
      'false'
    else
      nil
    end
  end

  def typed_champ_blank_or_invalid?(champ) = !champ_value_true?(champ)

  # 'on' / 'off', 'off' when blank
  def legacy_export_columns(procedure_id:)
    [legacy_export_column(procedure_id:, label: libelle, columns: canonical_column(procedure_id:)) { it ? 'on' : 'off' }]
  end

  def canonical_column(procedure_id:, displayable: true, prefix: nil)
    Columns::CheckboxColumn.new(
      procedure_id:,
      stable_id:,
      tdc_type: type_champ,
      label: libelle_with_prefix(prefix),
      type: self.class.column_type,
      displayable:,
      options_for_select:,
      mandatory: mandatory?
    )
  end

  private

  def champ_value_true?(champ) = champ.value == 'true'
end
