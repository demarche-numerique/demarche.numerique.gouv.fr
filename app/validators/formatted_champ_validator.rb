# frozen_string_literal: true

class FormattedChampValidator < ActiveModel::Validator
  def validate(record)
    if record.type_de_champ.formatted_mode == 'advanced'
      ExpressionReguliereValidator.new({ expression_reguliere_error_message: "n’est pas valide" }).validate(record)
    end

    if record.type_de_champ.formatted_mode == 'simple'
      SimpleFormattedChampValidator.new.validate(record)
    end
  end
end
