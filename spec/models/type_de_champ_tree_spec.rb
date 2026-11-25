# frozen_string_literal: true

describe TypeDeChampTree do
  let(:procedure) { create(:procedure, public_type_de_champs:, private_type_de_champs:) }
  let(:private_type_de_champs) { [] }
  let(:revision) { procedure.draft_revision }
  let(:tree) { revision.type_de_champ_tree }

  # the layout as nested libelles, a leaf being a libelle and a container a { libelle => children } pair
  def layout(nodes)
    libelles = revision.type_de_champs.to_h { [it.stable_id, it.libelle] }
    nodes.map { it.children.empty? ? libelles.fetch(it.stable_id) : { libelles.fetch(it.stable_id) => layout(it.children) } }
  end

  describe '#type_de_champ_ids' do
    let(:public_type_de_champs) do
      [
        { libelle: 'a' },
        { type: :header_section, level: 1, libelle: 'h1' },
        { type: :repetition, libelle: 'r', children: [{ type: :header_section, level: 1, libelle: 'rh1' }, { libelle: 'r1' }] },
        { libelle: 'b' },
      ]
    end
    let(:private_type_de_champs) { [{ libelle: 'c' }] }

    it 'lists every type de champ of the tree, whatever its depth, in document order' do
      expect(tree.type_de_champ_ids).to eq((revision.public_flat_type_de_champs + revision.private_flat_type_de_champs).map(&:id))
      expect(TypeDeChamp.where(id: tree.type_de_champ_ids).pluck(:libelle)).to match_array(['a', 'h1', 'r', 'rh1', 'r1', 'b', 'c'])
    end

    it 'is empty for an empty tree' do
      expect(described_class.new.type_de_champ_ids).to eq([])
    end

    it 'leaves out what the tree leaves out' do
      revision.remove_type_de_champ(revision.public_root_type_de_champs.find(&:repetition?).stable_id)

      expect(TypeDeChamp.where(id: tree.type_de_champ_ids).pluck(:libelle)).to match_array(['a', 'h1', 'b', 'c'])
    end
  end

  describe '.root_stable_ids' do
    let(:public_type_de_champs) do
      [
        { type: :header_section, level: 1, libelle: 'h1' },
        { type: :repetition, libelle: 'r', children: [{ type: :header_section, level: 1, libelle: 'rh1' }, { libelle: 'r1' }] },
        { libelle: 'a' },
      ]
    end
    let(:private_type_de_champs) { [{ libelle: 'b' }] }

    it 'gives the stable ids outside any repetition, the repetitions among them, once each' do
      libelles = revision.type_de_champs.to_h { [it.stable_id, it.libelle] }

      expect(described_class.root_stable_ids([tree, tree]).map { libelles.fetch(it) }).to eq(['h1', 'r', 'a', 'b'])
    end

    it 'is empty without any tree' do
      expect(described_class.root_stable_ids([])).to eq([])
    end
  end

  describe '#nodes_with_ancestors' do
    let(:public_type_de_champs) do
      [
        { type: :header_section, level: 1, libelle: 'h1' },
        { type: :repetition, libelle: 'r', children: [{ type: :header_section, level: 1, libelle: 'rh1' }, { libelle: 'r1' }] },
        { libelle: 'a' },
      ]
    end
    let(:private_type_de_champs) { [{ libelle: 'b' }] }

    def libelles(nodes_with_ancestors)
      libelles = revision.type_de_champs.to_h { [it.stable_id, it.libelle] }
      nodes_with_ancestors.map { |node, ancestors| [libelles.fetch(node.stable_id), ancestors.map { libelles.fetch(it.stable_id) }] }
    end

    it 'gives every node in document order with its ancestors, the outermost first' do
      expect(libelles(tree.nodes_with_ancestors)).to eq([
        ['h1', []], ['r', ['h1']], ['rh1', ['h1', 'r']], ['r1', ['h1', 'r', 'rh1']], ['a', ['h1']], ['b', []],
      ])
    end

    it 'gives the public nodes alone, or the private ones' do
      expect(libelles(tree.public_nodes_with_ancestors).map(&:first)).to eq(['h1', 'r', 'rh1', 'r1', 'a'])
      expect(libelles(tree.private_nodes_with_ancestors).map(&:first)).to eq(['b'])
    end
  end

  describe '#with_type_de_champ_ids' do
    let(:public_type_de_champs) { [{ type: :header_section, level: 1, libelle: 'h1' }, { type: :repetition, libelle: 'r', children: [{ libelle: 'r1' }] }] }
    let(:private_type_de_champs) { [{ libelle: 'c' }] }
    let(:ids) { tree.type_de_champ_ids.index_with { it + 1000 } }

    it 'lays out the types de champ given as the tree does the ones they stand in for' do
      other_tree = tree.with_type_de_champ_ids(ids)

      expect(other_tree.type_de_champ_ids).to eq(tree.type_de_champ_ids.map { it + 1000 })
      expect(other_tree.nodes.map(&:stable_id)).to eq(tree.nodes.map(&:stable_id))
      expect(layout(other_tree.public_children)).to eq([{ 'h1' => [{ 'r' => ['r1'] }] }])
      expect(layout(other_tree.private_children)).to eq(['c'])
    end

    it 'fails on a type de champ nothing stands in for' do
      expect { tree.with_type_de_champ_ids({}) }.to raise_error(KeyError)
    end
  end

  describe 'json' do
    let(:public_type_de_champs) { [{ type: :header_section, level: 1 }, { type: :repetition, children: [{}, {}] }] }
    let(:private_type_de_champs) { [{}] }

    it 'round trips' do
      expect(described_class.from_json(JSON.parse(tree.to_json))).to eq(tree)
    end

    it 'is made of plain ids' do
      type_de_champ = revision.private_root_type_de_champs.first

      expect(tree.as_json[:private_children]).to eq([{ stable_id: type_de_champ.stable_id, type_de_champ_id: type_de_champ.id, children: [] }])
    end
  end
end
