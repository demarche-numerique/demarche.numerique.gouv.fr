# frozen_string_literal: true

# The types de champ a TypeDeChampTree lays out, each one knowing its
# ancestors and its children (TypeDeChamp#lay_out). A revision lays out its
# own tree, a procedure the aggregate of the trees of its published revisions.
class TypeDeChampLayout < Data.define(
  :type_de_champs_by_stable_id,
  :public_type_de_champs, :public_flat_type_de_champs, :public_root_type_de_champs,
  :private_type_de_champs, :private_flat_type_de_champs, :private_root_type_de_champs
)
  class << self
    # Loads the types de champ of the tree in one query, but for the ones
    # given, which become the layout's own: an instance sits in one layout
    # only, as it knows where it sits.
    #
    # A node whose type de champ is gone is left out, with what it held.
    def lay_out(tree, type_de_champs_by_id = {})
      missing_ids = tree.type_de_champ_ids - type_de_champs_by_id.keys
      type_de_champs_by_id = type_de_champs_by_id.merge(TypeDeChamp.where(id: missing_ids).index_by(&:id)) if missing_ids.any?

      build(
        public_type_de_champs: TypeDeChamp.laid_out(tree.public_children) { type_de_champs_by_id[it.type_de_champ_id] },
        private_type_de_champs: TypeDeChamp.laid_out(tree.private_children) { type_de_champs_by_id[it.type_de_champ_id] }
      )
    end

    def build(public_type_de_champs:, private_type_de_champs:)
      public_flat_type_de_champs, private_flat_type_de_champs = [public_type_de_champs, private_type_de_champs]
        .map { |type_de_champs| type_de_champs.flat_map { [it, *it.flat_children] }.freeze }

      new(
        type_de_champs_by_stable_id: (public_flat_type_de_champs + private_flat_type_de_champs).index_by(&:stable_id).freeze,
        public_type_de_champs:,
        public_flat_type_de_champs:,
        public_root_type_de_champs: public_flat_type_de_champs.reject(&:in_repetition?).freeze,
        private_type_de_champs:,
        private_flat_type_de_champs:,
        private_root_type_de_champs: private_flat_type_de_champs.reject(&:in_repetition?).freeze
      )
    end
  end

  def type_de_champ(stable_id) = type_de_champs_by_stable_id[stable_id.to_i]

  # All types de champ in document order, the content of header sections and
  # repetitions inlined after them.
  def type_de_champs = public_flat_type_de_champs + private_flat_type_de_champs

  # root as in not within a repetition: header sections and their content are all there
  def root_type_de_champs = public_root_type_de_champs + private_root_type_de_champs
end
