# frozen_string_literal: true

class TypeDeChamps::LibelleValidator < ActiveModel::EachValidator
  def validate_each(procedure, attribute, types_de_champ)
    types_de_champ.reject(&:libelle_optionnal?).each do |tdc|
      validate_libelle(procedure, attribute, tdc)
    end
  end

  private

  def validate_libelle(procedure, attribute, tdc)
    return if tdc.libelle.present?

    draft = procedure.draft_revision
    parent = draft.parent_of(tdc)

    message_key, options = if parent
      [:missing_libelle_in_repetition, { position: position_of(draft, tdc), parent_position: position_of(draft, parent) }]
    else
      [:missing_libelle, { position: position_of(draft, tdc) }]
    end

    procedure.errors.add(
      attribute,
      procedure.errors.generate_message(attribute, message_key, options),
      type_de_champ: tdc
    )
  end

  # read off the loaded draft: another request may have removed the type de champ since
  def position_of(draft, tdc)
    siblings = if (parent = draft.parent_of(tdc))
      draft.children_of(parent)
    elsif tdc.public?
      draft.public_root_type_de_champs
    else
      draft.private_root_type_de_champs
    end

    siblings.index { it.stable_id == tdc.stable_id } + 1
  end
end
