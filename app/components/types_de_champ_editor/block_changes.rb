# frozen_string_literal: true

# What an edit changed in a block of the editor (the form, the annotations or
# what a repetition holds), told from the block before and after it: the page
# is brought up to date by removing, inserting and rendering again as little as
# it takes. Types de champ are named by their stable ids, a list by the stable
# id of the header section holding it, nil for the block itself.
class TypesDeChampEditor::BlockChanges
  # lists: what the block and each of its header sections hold, in document
  # order. signatures: what the card of a type de champ shows of where it sits.
  Snapshot = Data.define(:lists, :signatures, :type_champs) do
    # the types de champ of a block, laid out, in document order
    def self.of(type_de_champs)
      lists = { nil => [] }
      signatures = {}

      type_de_champs.each_with_index do |type_de_champ, index|
        stable_id = type_de_champ.stable_id
        section_stable_id = type_de_champ.parent.stable_id if type_de_champ.parent&.header_section?
        previous_sibling, next_sibling = type_de_champ.previous_sibling, type_de_champ.next_sibling

        lists[section_stable_id] << stable_id
        lists[stable_id] = [] if type_de_champ.header_section?
        signatures[stable_id] = [index, section_stable_id, previous_sibling&.header_section?, next_sibling.nil?, next_sibling&.header_section?]
      end

      new(lists:, signatures:, type_champs: type_de_champs.to_h { [it.stable_id, it.type_champ] })
    end

    def stable_ids = signatures.keys
    def include?(stable_id) = signatures.key?(stable_id)

    # a type de champ with all it holds
    def with_held(stable_id) = [stable_id, *lists.fetch(stable_id, []).flat_map { with_held(it) }]
  end

  # the list items to remove
  attr_reader :removed
  # the list items to render at their place, in document order
  attr_reader :inserted
  # the list items to render again, where they are
  attr_reader :replaced
  # the lists to render again
  attr_reader :replaced_lists
  # the cards to render again
  attr_reader :cards
  # the lists left empty, and the ones no longer so
  attr_reader :emptied, :filled

  # touched: the types de champ whose card is to be rendered again anyway
  def initialize(before:, after:, touched: [])
    @before = before
    @after = after
    @removed = []
    @inserted = []
    @replaced_lists = []
    # rendered again with what holds them
    @covered = Set.new

    # document order: a list comes before the ones within
    after.lists.each do |key, stable_ids|
      was = before.lists[key]
      # a header section added or which just became one comes with its list
      next if was.nil? || was == stable_ids || @covered.include?(key)

      moved = single_move(was, stable_ids, touched)

      if moved.nil?
        @replaced_lists << key
        stable_ids.each { cover(it) }
      else
        @removed << moved if before.include?(moved)
        @inserted << moved if stable_ids.include?(moved)
        cover(moved)
      end
    end

    @removed.uniq!
    @inserted.sort_by! { after.stable_ids.index(it) }
    # another type gives a list item another shape: a header section and a repetition hold a list
    @replaced = after.stable_ids.reject { @covered.include?(it) || !before.include?(it) || before.type_champs[it] == after.type_champs[it] }
    @replaced.each { cover(it) }
    @cards = after.stable_ids.reject { @covered.include?(it) }.filter { touched.include?(it) || before.signatures[it] != after.signatures[it] }
    @emptied, @filled = [true, false].map do |empty|
      after.lists.filter { |key, stable_ids| !@covered.include?(key) && before.lists.key?(key) && stable_ids.empty? == empty && before.lists[key].empty? != empty }.keys
    end
  end

  def any? = [removed, inserted, replaced, replaced_lists, cards].any?(&:present?)

  private

  def cover(stable_id) = @covered.merge(@after.with_held(stable_id))

  # The one type de champ which came in, went out or moved within a list,
  # everything else being as it was. nil when it takes more to tell the lists
  # apart.
  def single_move(was, stable_ids, touched)
    candidates = (was | stable_ids).filter { (was - [it]) == (stable_ids - [it]) }

    candidates.find { touched.include?(it) } || candidates.first
  end
end
