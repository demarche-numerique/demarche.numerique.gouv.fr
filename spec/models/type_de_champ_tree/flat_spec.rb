# frozen_string_literal: true

describe TypeDeChampTree::Flat do
  # a tree out of stable ids: a leaf is an id, a container an { id => children } pair
  def nodes(shape)
    shape.map do |entry|
      stable_id, children = entry.is_a?(Hash) ? entry.first : [entry, []]
      TypeDeChampNode.new(stable_id:, type_de_champ_id: stable_id + 100, children: nodes(children))
    end
  end

  def tree(public_children, private_children = []) = TypeDeChampTree.new(public_children: nodes(public_children), private_children: nodes(private_children))

  # by stable id, as the trees above are written
  def flatten(tree, repetitions: []) = tree.flatten(repetitions: repetitions.to_set { it + 100 })
  def fold(tree, levels: {}, repetitions: []) = tree.fold(levels: levels.transform_keys { it + 100 }, repetitions: repetitions.to_set { it + 100 })

  describe '#flatten' do
    it 'lays what the header sections hold after them, whatever the depth' do
      expect(flatten(tree([1, { 2 => [3, { 4 => [5] }, 6] }, { 7 => [8] }]))).to eq(tree([1, 2, 3, 4, 5, 6, 7, 8]))
    end

    it 'leaves a repetition what it holds, flattened as well' do
      expect(flatten(tree([{ 1 => [{ 2 => [3, { 4 => [5] }] }] }]), repetitions: [2])).to eq(tree([1, { 2 => [3, 4, 5] }]))
    end

    it 'flattens the annotations apart' do
      expect(flatten(tree([{ 1 => [2] }], [{ 3 => [4] }]))).to eq(tree([1, 2], [3, 4]))
    end
  end

  describe '#fold' do
    it 'gives a header section what follows it, up to the next one of its level or above' do
      folded = fold(tree([1, 2, 3, 4, 5, 6, 7, 8, 9]), levels: { 2 => 1, 4 => 2, 6 => 3, 8 => 1 })

      expect(folded).to eq(tree([1, { 2 => [3, { 4 => [5, { 6 => [7] }] }] }, { 8 => [9] }]))
    end

    it 'nests a header section in the nearest one of a lower level, however many levels are skipped' do
      expect(fold(tree([1, 2, 3, 4]), levels: { 1 => 1, 2 => 3, 4 => 2 })).to eq(tree([{ 1 => [{ 2 => [3] }, 4] }]))
    end

    it 'compares the levels as declared, not as nested' do
      expect(fold(tree([1, 2, 3]), levels: { 1 => 3, 2 => 2, 3 => 1 })).to eq(tree([1, 2, 3]))
    end

    it 'takes a level below 1 for 1' do
      expect(fold(tree([1, 2, 3]), levels: { 1 => 0, 3 => 1 })).to eq(tree([{ 1 => [2] }, 3]))
    end

    it 'folds what a repetition holds on its own' do
      folded = fold(tree([1, { 2 => [3, 4, 5] }, 6]), levels: { 1 => 1, 3 => 1, 5 => 1 }, repetitions: [2])

      expect(folded).to eq(tree([{ 1 => [{ 2 => [{ 3 => [4] }, 5] }, 6] }]))
    end

    it 'leaves out what anything but a repetition holds' do
      expect(fold(tree([{ 1 => [2] }, { 3 => [4] }, 5]), levels: { 3 => 1 })).to eq(tree([1, { 3 => [5] }]))
    end

    it 'folds the annotations apart' do
      expect(fold(tree([1, 2], [3, 4]), levels: { 1 => 1, 3 => 1 })).to eq(tree([{ 1 => [2] }], [{ 3 => [4] }]))
    end

    it 'gives back the tree flattened' do
      nested = tree([1, { 2 => [3, { 4 => [{ 5 => [6, { 7 => [8] }] }] }] }, 9], [{ 10 => [11] }])
      kinds = { levels: { 2 => 1, 4 => 2, 7 => 1, 9 => 1, 10 => 1 }, repetitions: [5] }

      expect(fold(flatten(nested, repetitions: [5]), **kinds)).to eq(nested)
    end
  end

  describe 'an edit of the flat tree' do
    let(:levels) { { 1 => 1, 4 => 1 } }
    let(:nested) { tree([{ 1 => [2, 3] }, { 4 => [5] }]) }

    it 'moves a header section without what it held' do
      expect(fold(flatten(nested).move(4, parent: :public, after: 2), levels:)).to eq(tree([{ 1 => [2] }, { 4 => [3, 5] }]))
    end

    it 'removes a header section without what it held' do
      expect(fold(flatten(nested).remove(4), levels:)).to eq(tree([{ 1 => [2, 3, 5] }]))
    end

    it 'gives a header section added what follows it' do
      added = flatten(nested).insert(nodes([6]).first, parent: :public, after: 2)

      expect(fold(added, levels: levels.merge(6 => 2))).to eq(tree([{ 1 => [2, { 6 => [3] }] }, { 4 => [5] }]))
    end
  end
end
