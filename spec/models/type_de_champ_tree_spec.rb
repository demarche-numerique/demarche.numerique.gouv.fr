# frozen_string_literal: true

describe TypeDeChampTree do
  let(:procedure) { create(:procedure, public_type_de_champs:, private_type_de_champs:) }
  let(:private_type_de_champs) { [] }
  let(:revision) { procedure.draft_revision }
  let(:tree) { described_class.from_coordinates(revision.revision_type_de_champs) }

  # the layout as nested libelles, a leaf being a libelle and a container a { libelle => children } pair
  def layout(nodes)
    libelles = revision.type_de_champs.to_h { [it.stable_id, it.libelle] }
    nodes.map { it.children.empty? ? libelles.fetch(it.stable_id) : { libelles.fetch(it.stable_id) => layout(it.children) } }
  end

  describe '.from_coordinates' do
    context 'without any header section' do
      let(:public_type_de_champs) { [{ libelle: 'a' }, { libelle: 'b' }] }
      let(:private_type_de_champs) { [{ libelle: 'c' }] }

      it 'keeps public and private apart' do
        expect(layout(tree.public_children)).to eq(['a', 'b'])
        expect(layout(tree.private_children)).to eq(['c'])
      end

      it 'points at the types de champ' do
        type_de_champ = revision.public_root_type_de_champs.first

        expect(tree.public_children.first).to eq(TypeDeChampNode.new(stable_id: type_de_champ.stable_id, type_de_champ_id: type_de_champ.id))
      end
    end

    context 'with a repetition' do
      let(:public_type_de_champs) { [{ libelle: 'a' }, { type: :repetition, libelle: 'r', children: [{ libelle: 'r1' }, { libelle: 'r2' }] }] }

      it { expect(layout(tree.public_children)).to eq(['a', { 'r' => ['r1', 'r2'] }]) }
    end

    context 'with well formed header sections' do
      let(:public_type_de_champs) do
        [
          { libelle: 'before' },
          { type: :header_section, level: 1, libelle: 'h1' },
          { libelle: 'a' },
          { type: :header_section, level: 2, libelle: 'h1.1' },
          { libelle: 'b' },
          { type: :header_section, level: 3, libelle: 'h1.1.1' },
          { libelle: 'c' },
          { type: :header_section, level: 2, libelle: 'h1.2' },
          { libelle: 'd' },
          { type: :header_section, level: 1, libelle: 'h2' },
          { libelle: 'e' },
        ]
      end

      it do
        expect(layout(tree.public_children)).to eq([
          'before',
          { 'h1' => ['a', { 'h1.1' => ['b', { 'h1.1.1' => ['c'] }] }, { 'h1.2' => ['d'] }] },
          { 'h2' => ['e'] },
        ])
      end
    end

    context 'with header sections inside a repetition' do
      let(:public_type_de_champs) do
        [
          { type: :header_section, level: 1, libelle: 'h1' },
          {
            type: :repetition, libelle: 'r', children: [
              { type: :header_section, level: 1, libelle: 'rh1' },
              { libelle: 'r1' },
              { type: :header_section, level: 2, libelle: 'rh1.1' },
              { libelle: 'r2' },
            ],
          },
          { libelle: 'a' },
        ]
      end

      it 'sections the repetition on its own' do
        expect(layout(tree.public_children)).to eq([
          { 'h1' => [{ 'r' => [{ 'rh1' => ['r1', { 'rh1.1' => ['r2'] }] }] }, 'a'] },
        ])
      end
    end

    context 'with a header section skipping a level' do
      let(:public_type_de_champs) do
        [
          { type: :header_section, level: 1, libelle: 'h1' },
          { type: :header_section, level: 3, libelle: 'h3' },
          { libelle: 'a' },
          { type: :header_section, level: 2, libelle: 'h2' },
          { libelle: 'b' },
        ]
      end

      it 'nests it in the nearest section of a lower level' do
        expect(layout(tree.public_children)).to eq([{ 'h1' => [{ 'h3' => ['a'] }, { 'h2' => ['b'] }] }])
      end
    end

    context 'with a first header section below level 1' do
      let(:public_type_de_champs) do
        [
          { type: :header_section, level: 3, libelle: 'h3' },
          { libelle: 'a' },
          { type: :header_section, level: 2, libelle: 'h2' },
          { libelle: 'b' },
        ]
      end

      it 'roots it' do
        expect(layout(tree.public_children)).to eq([{ 'h3' => ['a'] }, { 'h2' => ['b'] }])
      end
    end

    # TreeableConcern#to_tree nests this h3 in the h2 of the FIRST h1
    context 'with a level skipped after an earlier section of that level was closed' do
      let(:public_type_de_champs) do
        [
          { type: :header_section, level: 1, libelle: 'first h1' },
          { type: :header_section, level: 2, libelle: 'h2' },
          { type: :header_section, level: 1, libelle: 'second h1' },
          { type: :header_section, level: 3, libelle: 'h3' },
          { libelle: 'a' },
        ]
      end

      it 'never nests in a closed section' do
        expect(layout(tree.public_children)).to eq([{ 'first h1' => ['h2'] }, { 'second h1' => [{ 'h3' => ['a'] }] }])
      end
    end

    context 'whatever the header sections' do
      let(:public_type_de_champs) do
        [
          { libelle: 'before' },
          { type: :header_section, level: 2 },
          { type: :repetition, children: [{ type: :header_section, level: 3 }, {}, { type: :header_section, level: 1 }, {}] },
          { type: :header_section, level: 1 },
          { type: :header_section, level: 3 },
          {},
          { type: :header_section, level: 1 },
          { type: :header_section, level: 3 },
          {},
        ]
      end
      let(:private_type_de_champs) { [{ type: :header_section, level: 2 }, {}, { type: :header_section, level: 1 }, {}] }

      it 'preserves the document order' do
        expect(tree.nodes.map(&:stable_id))
          .to eq((revision.public_flat_type_de_champs + revision.private_flat_type_de_champs).map(&:stable_id))
      end
    end

    context 'with a child of a type de champ which is no longer a repetition' do
      let(:public_type_de_champs) { [{ type: :repetition, libelle: 'r', children: [{ libelle: 'r1' }] }, { libelle: 'a' }] }

      before do
        revision.public_root_type_de_champs.first.update_columns(type_champ: 'text')
        revision.reload
      end

      it 'leaves the unreachable child out' do
        expect(layout(tree.public_children)).to eq(['r', 'a'])
      end
    end

    context 'with a legacy type de champ without a type' do
      let(:public_type_de_champs) { [{ libelle: 'a' }, { libelle: 'b' }, { type: :repetition, libelle: 'r', children: [{ libelle: 'r1' }, { libelle: 'r2' }] }] }

      before do
        TypeDeChamp.where(libelle: ['a', 'r1'], id: revision.type_de_champs.map(&:id)).update_all(type_champ: nil)
        revision.reload
      end

      it 'leaves it out' do
        expect(layout(tree.public_children)).to eq(['b', { 'r' => ['r2'] }])
      end
    end

    context 'with a stable id held twice' do
      let(:public_type_de_champs) { [{ libelle: 'a' }, { type: :repetition, libelle: 'r', children: [{ libelle: 'r1' }, { libelle: 'r2' }] }, { libelle: 'b' }] }
      let(:repetition_coordinate) { revision.revision_type_de_champs.find(&:repetition?) }
      let(:r1) { revision.children_of(repetition_coordinate.type_de_champ).first }

      def copy_of(type_de_champ, libelle: type_de_champ.libelle)
        create(:type_de_champ_text, no_coordinate: true, libelle:).tap { it.update_columns(stable_id: type_de_champ.stable_id) }
      end

      def lay(type_de_champ, position:, parent: nil)
        revision.revision_type_de_champs.create!(type_de_champ:, position:, parent:)
        revision.reload
      end

      # revision 29448 of the 2026-09-07 snapshot
      context 'by the child of a repetition, also laid at the root along with a copy' do
        before do
          lay(r1, position: 0)
          lay(copy_of(r1), position: 1)
        end

        it 'keeps the child of the repetition' do
          expect(layout(tree.public_children)).to eq(['a', { 'r' => ['r1', 'r2'] }, 'b'])
          expect(tree.public_children.second.children.first.type_de_champ_id).to eq(r1.id)
        end
      end

      # revision 75985 of the 2026-09-07 snapshot
      context 'by the child of a repetition and the copy it was edited into' do
        let!(:edited) { copy_of(r1, libelle: 'r1 edited') }

        before { lay(edited, position: 0, parent: repetition_coordinate) }

        it 'keeps the latest type de champ' do
          expect(tree.public_children.second.children.map(&:type_de_champ_id)).to eq([edited.id, revision.children_of(repetition_coordinate.type_de_champ).last.id])
        end
      end

      context 'by two types de champ at the root' do
        let(:a) { revision.public_root_type_de_champs.first }
        let!(:edited) { copy_of(a, libelle: 'a edited') }

        before { lay(edited, position: 3) }

        it 'keeps the latest type de champ, where it is laid' do
          expect(tree.public_children.map(&:type_de_champ_id)).to eq([repetition_coordinate.type_de_champ_id, revision.public_root_type_de_champs.third.id, edited.id])
        end
      end
    end

    context 'with a revision not saved yet' do
      let(:procedure) { build(:procedure, public_type_de_champs:) }
      let(:public_type_de_champs) { [{ type: :header_section, level: 1, libelle: 'h1' }, { type: :repetition, libelle: 'r', children: [{ libelle: 'r1' }] }] }

      it do
        expect(revision).to be_new_record
        expect(tree.public_children.map { it.children.size }).to eq([1])
        expect(tree.public_children.first.children.map { it.children.size }).to eq([1])
      end
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
