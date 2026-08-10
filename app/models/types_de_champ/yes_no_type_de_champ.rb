# frozen_string_literal: true

class TypesDeChamp::YesNoTypeDeChamp < TypesDeChamp::TypeDeChampBase
  def filter_to_human(filter_value)
    if filter_value == "true"
      I18n.t('activerecord.attributes.type_de_champ.type_champs.yes_no_true')
    elsif filter_value == "false"
      I18n.t('activerecord.attributes.type_de_champ.type_champs.yes_no_false')
    else
      filter_value
    end
  end

  def filled_champ_value(champ)
    champ_value_true?(champ) ? 'Oui' : 'Non'
  end

  def filled_champ_value_for_export(champ, path = :value)
    champ_value_true?(champ) ? 'Oui' : 'Non'
  end

  def filled_champ_value_for_api(champ, version: 2)
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
