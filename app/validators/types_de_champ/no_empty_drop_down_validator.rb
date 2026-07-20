# frozen_string_literal: true

class TypesDeChamp::NoEmptyDropDownValidator < ActiveModel::EachValidator
  def validate_each(procedure, attribute, types_de_champ)
    types_de_champ
      .flat_map { with_children(procedure, it) }
      .filter(&:any_drop_down_list?)
      .each { validate_drop_down_not_empty(procedure, attribute, it) }
  end

  private

  def with_children(procedure, type_de_champ)
    return [type_de_champ] unless type_de_champ.repetition?

    [type_de_champ, *type_de_champ.flat_children(procedure.draft_revision)]
  end

  def validate_drop_down_not_empty(procedure, attribute, drop_down)
    if (drop_down.drop_down_list? || drop_down.multiple_drop_down_list?) && drop_down.drop_down_advanced? && drop_down.referentiel.blank?
      procedure.errors.add(
        attribute,
        procedure.errors.generate_message(attribute, :empty_csv, { value: drop_down.libelle }),
        type_de_champ: drop_down
      )

    elsif !drop_down.drop_down_advanced? && drop_down.drop_down_options.blank?
      procedure.errors.add(
        attribute,
        procedure.errors.generate_message(attribute, :empty_drop_down, { value: drop_down.libelle }),
        type_de_champ: drop_down
      )
    end
  end
end
