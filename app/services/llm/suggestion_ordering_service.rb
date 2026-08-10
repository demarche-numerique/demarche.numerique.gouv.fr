# frozen_string_literal: true

class LLM::SuggestionOrderingService
  ADD_KEY = 'add'
  UPDATE_KEY = 'update'

  def self.ordered_structure_suggestions(llm_rule_suggestion)
    merge_suggestions_into_originals(llm_rule_suggestion)
  end

  def self.build_original_list(revision)
    revision.public_revision_types_de_champ
      .to_a
   end

  def self.ordered_label_suggestions(llm_rule_suggestion)
    root_tdcs, children_tdcs = llm_rule_suggestion.llm_rule_suggestion_items
      .partition { |item| item.payload['parent_id'].nil? }
    children_by_parent_id = children_tdcs.group_by { |item| item.payload['parent_id'] }

    root_tdcs
      .sort_by { |item| item.payload['position'] }
      .flat_map do |root_item|
        [root_item] +
          (children_by_parent_id[root_item.payload['stable_id']] || []).sort_by { |item| item.payload['position'] }
      end
  end

  def self.merge_suggestions_into_originals(llm_rule_suggestion)
    suggestions = llm_rule_suggestion.llm_rule_suggestion_items.to_a
    original_items = llm_rule_suggestion.procedure_revision.public_revision_types_de_champ.to_a

    validate_no_cycles!(suggestions)

    suggestions_by_after_id = suggestions.index_by { |s| s.payload['after_stable_id'] }

    # Commencer par les suggestions en première position (after_stable_id: nil)
    result = suggestions_by_after_id[nil] ? [suggestions_by_after_id[nil]] : []

    # Parcourir les originaux et insérer les suggestions après chacun
    original_items.each_with_object(result) do |original, acc|
      acc << original
      acc << suggestions_by_after_id[original.stable_id] if suggestions_by_after_id[original.stable_id]
    end
  end

  def self.validate_no_cycles!(suggestions)
    return if suggestions.empty?

    after_ids = suggestions.map { |s| s.payload['after_stable_id'] }.compact

    # CAS 1 : Duplication - deux suggestions ne peuvent pas avoir le même after_stable_id
    if after_ids.uniq.length != after_ids.length
      raise "Cycle détecté : duplication d'after_stable_id"
    end

    # CAS 2 : Cycle fermé - tous les éléments se référencent mutuellement sans point d'entrée
    has_start = suggestions.any? { |s| s.payload['after_stable_id'].nil? }
    suggestion_ids = suggestions.map { |s| stable_id_of(s) }

    if !has_start && suggestion_ids.all? { |id| after_ids.include?(id) }
      raise "Cycle détecté : chaîne fermée sans point d'entrée"
    end
  end

  def self.stable_id_of(item)
    if item.is_a?(LLMRuleSuggestionItem)
      item.payload['stable_id'] || item.payload['generated_stable_id']
    else
      item.stable_id
    end
  end
end
