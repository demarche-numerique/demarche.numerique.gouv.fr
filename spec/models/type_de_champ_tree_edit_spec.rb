# frozen_string_literal: true

describe TypeDeChampTree do
  def node(stable_id, *children) = TypeDeChampNode.new(stable_id:, type_de_champ_id: stable_id * 10, children:)

  # the stable ids as they nest: [1, { 2 => [3] }]
  def shape(nodes) = nodes.map { it.children.empty? ? it.stable_id : { it.stable_id => shape(it.children) } }

  def chain(stable_ids) = stable_ids.reverse_each.reduce(nil) { |child, stable_id| node(stable_id, *child) }

  let(:tree) do
    described_class.new(
      public_children: [node(1), node(2, node(3), node(4, node(5))), node(6, node(7)), node(8)],
      private_children: [node(9)]
    )
  end

  describe '#insert' do
    it 'lays the node first of the parent' do
      expect(shape(tree.insert(node(20), parent: :public).public_children)).to eq([20, 1, { 2 => [3, { 4 => [5] }] }, { 6 => [7] }, 8])
      expect(shape(tree.insert(node(20), parent: :private).private_children)).to eq([20, 9])
      expect(shape(tree.insert(node(20), parent: 2).public_children)).to eq([1, { 2 => [20, 3, { 4 => [5] }] }, { 6 => [7] }, 8])
    end

    it 'lays the node after the sibling given' do
      expect(shape(tree.insert(node(20), parent: :public, after: 8).public_children)).to eq([1, { 2 => [3, { 4 => [5] }] }, { 6 => [7] }, 8, 20])
      expect(shape(tree.insert(node(20), parent: 2, after: 3).public_children)).to eq([1, { 2 => [3, 20, { 4 => [5] }] }, { 6 => [7] }, 8])
    end

    it 'lays the node in one holding nothing yet, with what it holds' do
      expect(shape(tree.insert(node(20, node(21)), parent: 5).public_children)).to eq([1, { 2 => [3, { 4 => [{ 5 => [{ 20 => [21] }] }] }] }, { 6 => [7] }, 8])
    end

    it 'gives another tree, as frozen as the first' do
      edited = tree.insert(node(20), parent: 2)

      expect(shape(tree.public_children)).to eq([1, { 2 => [3, { 4 => [5] }] }, { 6 => [7] }, 8])
      expect(edited.public_children).to be_frozen
      expect(edited.public_children.second.children).to be_frozen
    end

    it 'refuses a parent or a sibling which is not there' do
      expect { tree.insert(node(20), parent: 99) }.to raise_error(described_class::EditError, /99 is not in the tree/)
      expect { tree.insert(node(20), parent: 2, after: 7) }.to raise_error(described_class::EditError, /7 is not a child/)
      expect { tree.insert(node(20), parent: :public, after: 9) }.to raise_error(described_class::EditError, /9 is not a child/)
    end

    it 'refuses a stable id the tree holds' do
      expect { tree.insert(node(20, node(5)), parent: :public) }.to raise_error(described_class::EditError, /5 are already in the tree/)
    end
  end

  describe '#move' do
    it 'moves the node among its siblings' do
      expect(shape(tree.move(8, parent: :public).public_children)).to eq([8, 1, { 2 => [3, { 4 => [5] }] }, { 6 => [7] }])
      expect(shape(tree.move(1, parent: :public, after: 8).public_children)).to eq([{ 2 => [3, { 4 => [5] }] }, { 6 => [7] }, 8, 1])
      expect(shape(tree.move(4, parent: 2).public_children)).to eq([1, { 2 => [{ 4 => [5] }, 3] }, { 6 => [7] }, 8])
    end

    it 'moves the node to another parent, with what it holds' do
      expect(shape(tree.move(4, parent: 6, after: 7).public_children)).to eq([1, { 2 => [3] }, { 6 => [7, { 4 => [5] }] }, 8])
      expect(shape(tree.move(4, parent: :public, after: 2).public_children)).to eq([1, { 2 => [3] }, { 4 => [5] }, { 6 => [7] }, 8])
      expect(shape(tree.move(6, parent: 4, after: 5).public_children)).to eq([1, { 2 => [3, { 4 => [5, { 6 => [7] }] }] }, 8])
    end

    it 'does not tell the roots apart' do
      moved = tree.move(6, parent: :private, after: 9)

      expect(shape(moved.public_children)).to eq([1, { 2 => [3, { 4 => [5] }] }, 8])
      expect(shape(moved.private_children)).to eq([9, { 6 => [7] }])
    end

    it 'refuses a node, a parent or a sibling which is not there' do
      expect { tree.move(99, parent: :public) }.to raise_error(described_class::EditError, /99 is not in the tree/)
      expect { tree.move(1, parent: 99) }.to raise_error(described_class::EditError, /99 is not in the tree/)
      expect { tree.move(1, parent: 2, after: 7) }.to raise_error(described_class::EditError, /7 is not a child/)
      expect { tree.move(1, parent: :public, after: 1) }.to raise_error(described_class::EditError, /1 is not a child/)
    end

    it 'refuses to lay the node in what it holds' do
      expect { tree.move(2, parent: 2) }.to raise_error(described_class::EditError, /cannot go in what it holds/)
      expect { tree.move(2, parent: 5) }.to raise_error(described_class::EditError, /cannot go in what it holds/)
    end
  end

  describe '#remove' do
    it 'removes the node with what it holds' do
      expect(shape(tree.remove(2).public_children)).to eq([1, { 6 => [7] }, 8])
      expect(shape(tree.remove(5).public_children)).to eq([1, { 2 => [3, 4] }, { 6 => [7] }, 8])
      expect(shape(tree.remove(9).private_children)).to eq([])
    end

    it 'leaves what it holds in its place' do
      expect(shape(tree.remove(2, children: :inline).public_children)).to eq([1, 3, { 4 => [5] }, { 6 => [7] }, 8])
      expect(shape(tree.remove(4, children: :inline).public_children)).to eq([1, { 2 => [3, 5] }, { 6 => [7] }, 8])
      expect(shape(tree.remove(1, children: :inline).public_children)).to eq([{ 2 => [3, { 4 => [5] }] }, { 6 => [7] }, 8])
    end

    it 'refuses a node which is not there, or anything else to do with what it holds' do
      expect { tree.remove(99) }.to raise_error(described_class::EditError, /99 is not in the tree/)
      expect { tree.remove(2, children: :keep) }.to raise_error(ArgumentError, /:keep/)
    end
  end

  describe '#replace' do
    it 'gives the node another type de champ, and removes what it holds' do
      replaced = tree.replace(2, type_de_champ_id: 200)

      expect(shape(replaced.public_children)).to eq([1, 2, { 6 => [7] }, 8])
      expect(replaced.public_children.second.type_de_champ_id).to eq(200)
    end

    it 'keeps what it holds' do
      replaced = tree.replace(2, type_de_champ_id: 200, children: :keep)

      expect(shape(replaced.public_children)).to eq([1, { 2 => [3, { 4 => [5] }] }, { 6 => [7] }, 8])
      expect(replaced.public_children.second.type_de_champ_id).to eq(200)
      expect(replaced.public_children.second.children).to eq(tree.public_children.second.children)
    end

    it 'leaves what it holds right after it' do
      expect(shape(tree.replace(2, type_de_champ_id: 200, children: :inline).public_children)).to eq([1, 2, 3, { 4 => [5] }, { 6 => [7] }, 8])
      expect(shape(tree.replace(4, type_de_champ_id: 400, children: :inline).public_children)).to eq([1, { 2 => [3, 4, 5] }, { 6 => [7] }, 8])
    end

    it 'refuses a node which is not there, or anything else to do with what it holds' do
      expect { tree.replace(99, type_de_champ_id: 990) }.to raise_error(described_class::EditError, /99 is not in the tree/)
      expect { tree.replace(2, type_de_champ_id: 200, children: :drop) }.to raise_error(ArgumentError, /:drop/)
    end
  end

  describe 'the depth' do
    # three header sections, a repetition, three header sections: 107 has seven ancestors
    let(:deepest) { described_class.new(public_children: [chain(100..107), node(1, node(2))]) }

    it 'holds a node under seven ancestors' do
      expect(deepest.nodes_with_ancestors.map { |_, ancestors| ancestors.size }.max).to eq(described_class::MAX_DEPTH)

      node, ancestors = deepest.move(2, parent: 106, after: 107).nodes_with_ancestors.find { |node, _| node.stable_id == 2 }
      expect(ancestors.map(&:stable_id)).to eq([*100..106])
      expect(ancestors.last.children.map(&:stable_id)).to eq([107, node.stable_id])
    end

    it 'refuses a node under more of them' do
      expect { deepest.insert(node(20), parent: 107) }.to raise_error(described_class::TooDeepError)
      expect { deepest.move(2, parent: 107) }.to raise_error(described_class::TooDeepError)
    end

    it 'counts what the node holds' do
      expect { deepest.move(1, parent: 106) }.to raise_error(described_class::TooDeepError)
      expect { deepest.insert(chain(200..208), parent: :public) }.to raise_error(described_class::TooDeepError)
      expect(deepest.insert(chain(200..207), parent: :private).private_children.size).to eq(1)
    end
  end
end
