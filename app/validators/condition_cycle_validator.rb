# frozen_string_literal: true

# Un champ public conditionné sur une annotation (#14251) rend constructible un cycle
# public ↔ privé, invisible pour ConditionValidator qui ne voit qu'une collection à la fois.
# Un cycle fait récurser Champ#visible? indéfiniment.
class ConditionCycleValidator < ActiveModel::Validator
  def validate(revision)
    coordinates = revision.revision_type_de_champs.index_by(&:stable_id)
    edges = coordinates.values.filter { it.type_de_champ.condition? }.to_h do |coordinate|
      sources = coordinate.type_de_champ.condition.sources.filter { visible_from?(coordinates[it], coordinate) }
      [coordinate.stable_id, sources]
    end
    cycle = find_cycle(edges)
    return if cycle.nil?

    tdcs = coordinates.values_at(*cycle).map(&:type_de_champ)
    revision.errors.add(:base, :condition_cycle,
      type_de_champ: tdcs.first, libelles: [*tdcs, tdcs.first].map { it.libelle.truncate(50) }.join(' → '))
  end

  private

  # Comme Champ#visible? : un champ racine ne voit que les champs racine, un enfant y ajoute sa ligne.
  def visible_from?(source, coordinate)
    source.present? && (source.root? || source.parent_id == coordinate.parent_id)
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
