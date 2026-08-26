# frozen_string_literal: true

class TypesDeChamp::PrefillSiret < TypesDeChamp::Prefill
  def example_value
    "130 025 265 00013"
  end

  def to_assignable_attributes(champ, value)
    return nil if !scalar_prefill_value?(value)
    { external_id: value.to_s.presence }
  end
end
