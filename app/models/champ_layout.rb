# frozen_string_literal: true

# The champs of a dossier on its stream, laid out as the types de champ of its
# revision are (Dossier#champ_layout). A champ data instance is shared by every
# stream the dossier switches to, so a champ holds no place of its own: it
# finds it here by public id. The rows are built here, and hold their children.
class ChampLayout < Data.define(
  :public_champs, :private_champs,
  :public_flat_champs, :private_flat_champs,
  :public_root_champs, :private_root_champs,
  :champs_by_row_id,
  :ancestors_by_public_id, :children_by_public_id, :rows_by_stable_id, :row_by_public_id
)
  class NotLaidOutError < StandardError
    def initialize(champ)
      super("champ #{champ.public_id} was not laid out: get it from its dossier")
    end
  end

  def self.lay_out(dossier) = Builder.new(dossier).build

  # All champs in document order, the content of header sections and rows
  # inlined after them.
  def champs = public_flat_champs + private_flat_champs

  # what a champ on `row_id` can reference: its own row, and what sits outside
  # repetitions; a champ outside any repetition sees only the latter
  def champs_for_row(row_id)
    return champs_by_row_id.fetch(nil, []) if row_id.nil?

    champs_by_row_id.fetch(row_id, []) + champs_by_row_id.fetch(nil, [])
  end

  def ancestors(champ) = fetch(ancestors_by_public_id, champ)
  def children(header_section) = fetch(children_by_public_id, header_section)
  # a repetition is never nested: its stable id is enough, and serves its row champs too
  def rows(repetition) = rows_by_stable_id.fetch(repetition.stable_id) { raise NotLaidOutError, repetition }
  def row(champ) = fetch(row_by_public_id, champ)

  private

  def fetch(by_public_id, champ) = by_public_id.fetch(champ.public_id) { raise NotLaidOutError, champ }

  class Builder
    def initialize(dossier)
      @dossier = dossier
      @ancestors = {}
      @children = {}
      @rows = {}
      @row_of = {}
    end

    def build
      public_flat_champs = []
      private_flat_champs = []
      public_champs = walk(@dossier.revision.public_type_de_champs, ancestors: [], row: nil, flat: public_flat_champs)
      private_champs = walk(@dossier.revision.private_type_de_champs, ancestors: [], row: nil, flat: private_flat_champs)

      ChampLayout.new(
        public_champs:,
        private_champs:,
        public_flat_champs: public_flat_champs.freeze,
        private_flat_champs: private_flat_champs.freeze,
        public_root_champs: public_flat_champs.reject(&:in_repetition?).freeze,
        private_root_champs: private_flat_champs.reject(&:in_repetition?).freeze,
        champs_by_row_id: (public_flat_champs + private_flat_champs).group_by(&:row_id).freeze,
        ancestors_by_public_id: @ancestors.freeze,
        children_by_public_id: @children.freeze,
        rows_by_stable_id: @rows.freeze,
        row_by_public_id: @row_of.freeze
      )
    end

    private

    def walk(type_de_champs, ancestors:, row:, flat:)
      type_de_champs.map do |type_de_champ|
        champ = @dossier.project_champ(type_de_champ, row_id: row&.id)
        @ancestors[champ.public_id] = ancestors
        @row_of[champ.public_id] = row
        flat << champ

        if type_de_champ.header_section?
          @children[champ.public_id] = walk(type_de_champ.children, ancestors: [*ancestors, champ].freeze, row:, flat:)
        elsif type_de_champ.repetition?
          @rows[champ.stable_id] = lay_out_rows(champ, ancestors: [*ancestors, champ].freeze, flat:)
        end

        champ
      end.freeze
    end

    def lay_out_rows(repetition, ancestors:, flat:)
      @dossier.repetition_row_ids(repetition.type_de_champ).map.with_index(1) do |row_id, index|
        row = RepetitionRow.new(id: row_id, index:, repetition:)
        row.lay_out(children: walk(repetition.type_de_champ.children, ancestors:, row:, flat:))
      end.freeze
    end
  end
end
