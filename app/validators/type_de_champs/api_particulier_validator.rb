# frozen_string_literal: true

class TypeDeChamps::APIParticulierValidator < ActiveModel::EachValidator
  def validate_each(procedure, attribute, types_de_champ)
    types_de_champ.filter(&:api_particulier?).each do |api_part_tdc|
      validate_api_particulier_token_usable(procedure, attribute, api_part_tdc)
    end
  end

  private

  def validate_api_particulier_token_usable(procedure, attribute, api_part_tdc)
    if procedure.api_particulier_token.unusable?
      procedure.errors.add(
        attribute,
        :missing_api_particulier_token,
        value: api_part_tdc.libelle,
        type_de_champ: api_part_tdc
      )
    end
  end
end
