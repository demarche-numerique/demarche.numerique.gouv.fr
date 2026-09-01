# frozen_string_literal: true

class TypeDeChamps::ConditionValidator < ActiveModel::EachValidator
  # condition are valid when
  #   tdc.condition.left is present in upper tdcs
  #   in case of private type_de_champs, we should include public type_de_champs too
  def validate_each(procedure, collection, tdcs)
    return if tdcs.empty?

    tdcs.each_with_index do |tdc, tdc_index|
      next unless tdc.condition?

      upper_tdcs = []
      if collection == :private_draft_type_de_champs # in case of private tdc validation, we must include public tdcs
        upper_tdcs += procedure.public_draft_type_de_champs
      end
      upper_tdcs += tdcs.take(tdc_index) # we take all upper_tdcs of current tdcs

      errors = Logic.errors(tdc.condition, upper_tdcs)
      next if errors.blank?

      procedure.errors.add(
        collection,
        procedure.errors.generate_message(collection, :invalid_condition, { value: tdc.libelle }),
        type_de_champ: tdc
      )
    end
  end
end
