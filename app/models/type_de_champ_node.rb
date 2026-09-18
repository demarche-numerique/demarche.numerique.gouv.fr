# frozen_string_literal: true

# A type de champ placed in a TypeDeChampTree. Only repetitions and header
# sections have children.
class TypeDeChampNode < Data.define(:stable_id, :type_de_champ_id, :children)
  def self.from_json(json)
    json = json.symbolize_keys

    new(
      stable_id: json.fetch(:stable_id),
      type_de_champ_id: json.fetch(:type_de_champ_id),
      children: json.fetch(:children).map { from_json(it) }
    )
  end

  def initialize(stable_id:, type_de_champ_id:, children: [])
    super(stable_id:, type_de_champ_id:, children: children.freeze)
  end

  def as_json(*) = { stable_id:, type_de_champ_id:, children: children.map(&:as_json) }
end
