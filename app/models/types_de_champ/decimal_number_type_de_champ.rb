# frozen_string_literal: true

class TypesDeChamp::DecimalNumberTypeDeChamp < TypesDeChamp::TypeDeChampBase
  def filled_champ_value_for_export(champ, path = :value)
    champ_formatted_value(champ)
  end

  def filled_champ_value_for_api(champ, version: 2)
    case version
    when 1
      champ_formatted_value(champ)
    else
      super
    end
  end

  def champ_default_export_value(path = :value)
    0
  end

  private

  def champ_formatted_value(champ)
    champ.value&.to_f
  end
end
