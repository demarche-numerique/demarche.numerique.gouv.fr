# frozen_string_literal: true

class TypesDeChamp::PrefillAddressTypeDeChamp < TypesDeChamp::PrefillTypeDeChamp
  def to_assignable_attributes(champ, value)
    return nil if !value.is_a?(String) || value.blank?
    { id: champ.id, value: value, external_id: value }
  end
end
