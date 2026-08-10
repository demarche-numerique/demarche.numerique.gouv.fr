# frozen_string_literal: true

class TypesDeChamp::ConditionValidator < ActiveModel::EachValidator
  # condition are valid when
  #   tdc.condition.left is present in upper tdcs
  #   in case of private_types_de_champ, we should include types_de_champ_publics too
  def validate_each(procedure, collection, tdcs)
    return if tdcs.empty?

    tdcs.each_with_index do |tdc, tdc_index|
      next unless tdc.condition?

      upper_tdcs = []
      if collection == :draft_private_types_de_champ # in case of private tdc validation, we must include public tdcs
        upper_tdcs += procedure.draft_public_types_de_champ
      end
      upper_tdcs += tdcs.take(tdc_index) # we take all upper_tdcs of current tdcs

      errors = tdc.condition.errors(upper_tdcs)
      next if errors.blank?

      procedure.errors.add(
        collection,
        procedure.errors.generate_message(collection, :invalid_condition, { value: tdc.libelle }),
        type_de_champ: tdc
      )
    end
  end
end
