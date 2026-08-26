# frozen_string_literal: true

class TypesDeChamp::YesNo < TypeDeChamp
  def self.category = CHOICE
  def self.column_type = :boolean
  def self.conditionable? = true

  def prefillable? = true
  def condition_value_type = :boolean

  def typed_champ_value(champ)
    champ_value_true?(champ) ? 'Oui' : 'Non'
  end

  def typed_champ_value_for_export(champ, path = :value)
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

  def champ_default_export_value(path = :value)
    ''
  end

  private

  def champ_value_true?(champ)
    champ.value == 'true'
  end
end
