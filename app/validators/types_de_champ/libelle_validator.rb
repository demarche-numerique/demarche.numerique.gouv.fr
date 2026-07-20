# frozen_string_literal: true

class TypesDeChamp::LibelleValidator < ActiveModel::EachValidator
  def validate_each(procedure, attribute, types_de_champ)
    types_de_champ.each do |tdc|
      validate_libelle(procedure, attribute, tdc)

      next unless tdc.repetition?

      tdc.flat_children(procedure.draft_revision).each do |child|
        validate_libelle(procedure, attribute, child, parent: tdc)
      end
    end
  end

  private

  def validate_libelle(procedure, attribute, tdc, parent: nil)
    return if tdc.libelle.present?

    message_key, options = if parent
      [:missing_libelle_in_repetition, { position: position_of(tdc), parent_position: position_of(parent) }]
    else
      [:missing_libelle, { position: position_of(tdc) }]
    end

    procedure.errors.add(
      attribute,
      procedure.errors.generate_message(attribute, message_key, options),
      type_de_champ: tdc
    )
  end

  def position_of(tdc) = tdc.revision_types_de_champ.last.position + 1
end
