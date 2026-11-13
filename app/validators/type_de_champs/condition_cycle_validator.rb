# frozen_string_literal: true

# Un champ public conditionné sur une annotation (#14251) rend constructible un cycle
# public ↔ privé, invisible pour ConditionValidator qui ne voit qu'une collection à la fois.
# Un cycle fait récurser Champ#visible? indéfiniment.
class TypeDeChamps::ConditionCycleValidator < ActiveModel::EachValidator
  def validate_each(procedure, attribute, tdcs)
    tdcs_by_stable_id = tdcs.index_by(&:stable_id)
    edges = tdcs.filter(&:condition?).to_h do |tdc|
      sources = tdc.condition.sources.filter { visible_from?(tdcs_by_stable_id[it], tdc) }
      [tdc.stable_id, sources]
    end
    cycle = find_cycle(edges)
    return if cycle.nil?

    cycle_tdcs = tdcs_by_stable_id.values_at(*cycle)
    procedure.errors.add(attribute, :condition_cycle,
      type_de_champ: cycle_tdcs.first, libelles: [*cycle_tdcs, cycle_tdcs.first].map { it.libelle.truncate(50) }.join(' → '))
  end

  private

  # Comme Champ#visible? : un champ hors répétition ne voit que les champs hors répétition,
  # un enfant y ajoute sa ligne.
  def visible_from?(source, tdc)
    return false if source.nil?
    return true if !source.in_repetition?

    source.enclosing_repetition.stable_id == tdc.enclosing_repetition&.stable_id
  end

  def find_cycle(edges)
    visited = Set.new

    edges.each_key do |stable_id|
      cycle = walk(stable_id, edges, [], visited)
      return cycle if cycle
    end

    nil
  end

  # `path` est la pile courante : retomber sur un stable_id qui y figure déjà est une arête
  # arrière, et `path[index..]` en est exactement la boucle.
  def walk(stable_id, edges, path, visited)
    index = path.index(stable_id)
    return path[index..] if index
    return nil if visited.include?(stable_id)

    path.push(stable_id)

    edges.fetch(stable_id, []).each do |source_id|
      cycle = walk(source_id, edges, path, visited)
      return cycle if cycle
    end

    path.pop
    visited << stable_id
    nil
  end
end
