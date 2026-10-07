# frozen_string_literal: true

class TypesDeChamp::YesNoTypeDeChamp < TypeDeChamp
  def self.category = CHOICE
  def self.icon = 'fr-icon-toggle-line'
  def self.column_type = :boolean
  def self.conditionable? = true

  def prefillable? = true
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
    ''
  end

  # 'Oui' / 'Non', '' when blank
  def legacy_export_columns(procedure_id:)
    [legacy_export_column(procedure_id:, label: libelle, columns: canonical_column(procedure_id:)) { it.nil? ? '' : (it ? 'Oui' : 'Non') }]
  end

  private

  def champ_value_true?(champ)
    champ.value == 'true'
  end
end
