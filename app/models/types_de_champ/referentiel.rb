# frozen_string_literal: true

class TypesDeChamp::Referentiel < TypeDeChamp
  def self.category = REFERENTIEL_EXTERNE
  def self.option_keys = [:referentiel_mapping]

  store_accessor :options, :referentiel_mapping

  def prefillable? = referentiel_in_exact_match?

  def referentiel_in_exact_match? = referentiel.present? && referentiel.exact_match?

  def safe_referentiel_mapping
    Hash(referentiel_mapping).with_indifferent_access
  end

  def referentiel_mapping_prefillable
    safe_referentiel_mapping.filter { |_jsonpath, mapping_opts| mapping_opts[:prefill] == "1" }
  end

  def referentiel_mapping_prefillable_with_stable_id
    referentiel_mapping_prefillable.filter { |_jsonpath, mapping_opts| mapping_opts[:prefill_stable_id].present? }
  end

  def referentiel_mapping_prefillable_stable_ids
    referentiel_mapping_prefillable_with_stable_id.map { |_jsonpath, mapping_opts| mapping_opts[:prefill_stable_id] }
  end

  def referentiel_mapping_displayable
    safe_referentiel_mapping.filter { |_jsonpath, mapping_opts| mapping_opts[:prefill] != "1" }
  end

  def referentiel_mapping_displayable_for_instructeur
    referentiel_mapping_displayable.filter { |_jsonpath, mapping| mapping[:display_instructeur] == "1" }
  end

  def referentiel_mapping_displayable_for_usager
    referentiel_mapping_displayable.filter { |_jsonpath, mapping| mapping[:display_usager] == "1" }
  end
end
