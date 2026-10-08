# frozen_string_literal: true

class TypesDeChamp::PrefillIbanTypeDeChamp < TypesDeChamp::PrefillTypeDeChamp
  # IBAN prefill is withdrawn: only the procedures that already relied on it keep it.
  def prefillable? = @revision.procedure.feature_enabled?(:prefill_iban)
end
