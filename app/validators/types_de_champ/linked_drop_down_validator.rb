# frozen_string_literal: true

class TypesDeChamp::LinkedDropDownValidator < ActiveModel::EachValidator
  def validate_each(procedure, attribute, types_de_champ)
    types_de_champ
      .filter(&:linked_drop_down_list?)
      .each { validate_starts_with_primary_option(procedure, attribute, it) }
  end

  private

  def validate_starts_with_primary_option(procedure, attribute, type_de_champ)
    return if TypesDeChamp::LinkedDropDownListTypeDeChamp::PRIMARY_PATTERN.match?(type_de_champ.drop_down_options.first)

    procedure.errors.add(
      attribute,
      procedure.errors.generate_message(attribute, :missing_primary_option, { value: type_de_champ.libelle }),
      type_de_champ:
    )
  end
end
