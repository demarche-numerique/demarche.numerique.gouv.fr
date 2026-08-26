# frozen_string_literal: true

class TypesDeChamp::PrefillAddress < TypesDeChamp::Prefill
  def to_assignable_attributes(champ, value)
    return nil if !value.is_a?(String) || value.blank?
    { value: value, external_id: value }
  end
end
