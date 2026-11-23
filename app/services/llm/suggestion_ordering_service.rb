# frozen_string_literal: true

class LLM::SuggestionOrderingService
  ADD_KEY = 'add'
  UPDATE_KEY = 'update'

  def self.ordered_structure_suggestions(llm_rule_suggestion)
    merge_suggestions_into_originals(llm_rule_suggestion)
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

    validate_no_cycles!(suggestions)

    suggestions_by_place = suggestions.index_by { |s| place_of(s) }

    lay(nil, llm_rule_suggestion.procedure_revision.public_type_de_champs, suggestions_by_place)
  end

  # Le formulaire dans l'ordre qu'il prend une fois les suggestions appliquées
  # (RevisionEditConcern#apply_llm_rule_suggestion_items) : une suggestion placée
  # en premier dans une section vient juste après son titre, une suggestion
  # placée après un champ vient après tout ce qu'il contient.
  def self.lay(parent_stable_id, type_de_champs, suggestions_by_place)
    type_de_champs.reduce(chain([:first, parent_stable_id], suggestions_by_place)) do |acc, type_de_champ|
      acc << type_de_champ
      acc.concat(lay(type_de_champ.stable_id, type_de_champ.header_section? ? type_de_champ.children : [], suggestions_by_place))
      acc.concat(chain([:after, type_de_champ.stable_id], suggestions_by_place))
    end
  end

  # Où se place une suggestion : après un champ, sinon en premier dans une
  # section, ou dans le formulaire.
  def self.place_of(suggestion)
    after_stable_id, parent_stable_id = suggestion.payload.values_at('after_stable_id', 'parent_stable_id')

    after_stable_id.nil? ? [:first, parent_stable_id] : [:after, after_stable_id]
  end

  # La suggestion placée ici, suivie de celles placées dans la section qu'elle
  # ajoute, puis après elle. Chacune n'est prise qu'une fois : des identifiants
  # incohérents ne font pas boucler.
  def self.chain(place, suggestions_by_place)
    suggestion = suggestions_by_place.delete(place)
    return [] if suggestion.nil?

    generated_stable_id = suggestion.payload['generated_stable_id']
    return [suggestion] if generated_stable_id.nil?

    [suggestion, *chain([:first, generated_stable_id], suggestions_by_place), *chain([:after, generated_stable_id], suggestions_by_place)]
  end

  def self.validate_no_cycles!(suggestions)
    return if suggestions.empty?

    places = suggestions.map { |s| place_of(s) }
    # le début du formulaire n'est l'ancre de personne
    anchored_places = places.reject { |(_, stable_id)| stable_id.nil? }

    # CAS 1 : Duplication - deux suggestions ne peuvent pas se placer au même endroit
    if anchored_places.uniq.length != anchored_places.length
      raise "Cycle détecté : duplication d'after_stable_id"
    end

    # CAS 2 : Cycle fermé - tous les éléments se référencent mutuellement sans point d'entrée
    has_start = anchored_places.length != places.length
    anchor_ids = anchored_places.map(&:last)
    suggestion_ids = suggestions.map { |s| stable_id_of(s) }

    if !has_start && suggestion_ids.all? { |id| anchor_ids.include?(id) }
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
