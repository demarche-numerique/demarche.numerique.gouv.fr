# frozen_string_literal: true

# The types de champ a TypeDeChampTree lays out, each one knowing its
# ancestors and its children (TypeDeChamp#lay_out).
class TypeDeChampLayout < Data.define(:type_de_champs_by_stable_id, :public_type_de_champs, :private_type_de_champs)
  class << self
    # Loads the types de champ of the tree in one query. A node whose type de
    # champ is gone is left out, with what it held.
    def lay_out(tree)
      type_de_champs_by_id = TypeDeChamp.where(id: tree.type_de_champ_ids).index_by(&:id)

      build(
        public_type_de_champs: TypeDeChamp.laid_out(tree.public_children) { type_de_champs_by_id[it.type_de_champ_id] },
        private_type_de_champs: TypeDeChamp.laid_out(tree.private_children) { type_de_champs_by_id[it.type_de_champ_id] }
      )
    end

    def build(public_type_de_champs:, private_type_de_champs:)
      type_de_champs = (public_type_de_champs + private_type_de_champs).flat_map { [it, *it.flat_children] }

      new(type_de_champs_by_stable_id: type_de_champs.index_by(&:stable_id).freeze, public_type_de_champs:, private_type_de_champs:)
    end
  end

  def type_de_champ(stable_id) = type_de_champs_by_stable_id[stable_id.to_i]
end
