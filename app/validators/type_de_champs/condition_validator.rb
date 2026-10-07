# frozen_string_literal: true

class TypeDeChamps::ConditionValidator < ActiveModel::EachValidator
  # Une condition peut citer n'importe quel champ de l'autre visibilité ; dans sa propre
  # collection, seulement ceux au-dessus.
  def validate_each(procedure, collection, tdcs)
    return if tdcs.empty?

    tdcs.each_with_index do |tdc, tdc_index|
      next unless tdc.condition?

      upper_tdcs = if collection == :private_draft_type_de_champs
        procedure.public_draft_type_de_champs
      else
        procedure.private_draft_type_de_champs
      end

      upper_tdcs += tdcs.take(tdc_index)

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
