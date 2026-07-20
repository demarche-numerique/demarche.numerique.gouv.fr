# frozen_string_literal: true

class TypesDeChamp::ConditionValidator < ActiveModel::EachValidator
  # condition are valid when
  #   tdc.condition.left is present in upper tdcs
  #   in case of types_de_champ_private, we should include types_de_champ_publics too
  def validate_each(procedure, collection, tdcs)
    return if tdcs.empty?

    tdcs = tdcs_with_children(procedure, tdcs)
    tdcs.each_with_index do |tdc, tdc_index|
      next unless tdc.condition?

      upper_tdcs = []
      if collection == :draft_types_de_champ_private # in case of private tdc validation, we must include public tdcs
        upper_tdcs += tdcs_with_children(procedure, procedure.draft_types_de_champ_public)
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

  # find children in repetitions, keeping the repetition itself so its own
  # condition is validated too
  def tdcs_with_children(procedure, tdcs)
    tdcs.to_a
      .flat_map { it.repetition? ? [it, *it.flat_children(procedure.draft_revision)] : it }
  end
end
