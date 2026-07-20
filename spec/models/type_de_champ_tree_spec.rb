# frozen_string_literal: true

describe TypeDeChampTree do
  subject(:tree) do
    TypeDeChampTree.new(
      public_coordinates: draft.revision_types_de_champ_public,
      private_coordinates: draft.revision_types_de_champ_private
    )
  end

  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:draft) { procedure.draft_revision }

  let(:header_1) { { type: :header_section, level: 1, stable_id: 99 } }
  let(:header_1_2) { { type: :header_section, level: 2, stable_id: 199 } }
  let(:header_2) { { type: :header_section, level: 1, stable_id: 299 } }
  let(:champ_text) { { stable_id: 399 } }
  let(:champ_textarea) { { type: :textarea, stable_id: 499 } }
  let(:champ_explication) { { type: :explication, stable_id: 599 } }
  let(:champ_communes) { { type: :communes, stable_id: 699 } }

  def tdc(stable_id) = tree.type_de_champ(stable_id)

  describe 'without section' do
    let(:types_de_champ_public) { [champ_text, champ_textarea] }

    it 'inlines champs at root level' do
      expect(tree.roots_public).to eq([tdc(399), tdc(499)])
      expect(tree.children_of(tdc(399))).to eq([])
      expect(tree.ancestors_of(tdc(399))).to eq([])
    end
  end

  describe 'with header sections and champs' do
    let(:types_de_champ_public) { [header_1, champ_explication, champ_text, header_2, champ_textarea] }

    it 'collapses each section content into its header' do
      expect(tree.roots_public).to eq([tdc(99), tdc(299)])
      expect(tree.children_of(tdc(99))).to eq([tdc(599), tdc(399)])
      expect(tree.children_of(tdc(299))).to eq([tdc(499)])
      expect(tree.ancestors_of(tdc(399))).to eq([tdc(99)])
    end
  end

  describe 'with leading champs before the first section' do
    let(:types_de_champ_public) { [champ_text, champ_textarea, header_1, champ_explication, champ_communes, header_2] }

    it 'keeps leading champs at root level' do
      expect(tree.roots_public).to eq([tdc(399), tdc(499), tdc(99), tdc(299)])
      expect(tree.children_of(tdc(99))).to eq([tdc(599), tdc(699)])
    end
  end

  describe 'with a sub section' do
    let(:types_de_champ_public) { [header_1, champ_explication, header_1_2, champ_communes, header_2, champ_textarea] }

    it 'nests the sub section under its header' do
      expect(tree.roots_public).to eq([tdc(99), tdc(299)])
      expect(tree.children_of(tdc(99))).to eq([tdc(599), tdc(199)])
      expect(tree.children_of(tdc(199))).to eq([tdc(699)])
      expect(tree.ancestors_of(tdc(699))).to eq([tdc(99), tdc(199)])
    end
  end

  describe 'with consecutive sub sections' do
    let(:header_1_2_bis) { { type: :header_section, level: 2, stable_id: 899 } }
    let(:types_de_champ_public) { [header_1, header_1_2, champ_text, header_1_2_bis, champ_textarea] }

    it 'closes a sub section when the next one starts' do
      expect(tree.roots_public).to eq([tdc(99)])
      expect(tree.children_of(tdc(99))).to eq([tdc(199), tdc(899)])
      expect(tree.children_of(tdc(199))).to eq([tdc(399)])
      expect(tree.children_of(tdc(899))).to eq([tdc(499)])
    end
  end

  describe 'with a skipped header level (h1 then h3, no h2)' do
    let(:header_1_3) { { type: :header_section, level: 3, stable_id: 799 } }
    let(:types_de_champ_public) { [header_1, champ_text, header_1_3, champ_textarea] }

    it 'attaches to the nearest existing ancestor' do
      expect(tree.roots_public).to eq([tdc(99)])
      expect(tree.children_of(tdc(99))).to eq([tdc(399), tdc(799)])
      expect(tree.ancestors_of(tdc(499))).to eq([tdc(99), tdc(799)])
    end
  end

  describe 'with a sub section closing a deeper one' do
    let(:header_1_2_3) { { type: :header_section, level: 3, stable_id: 799 } }
    let(:types_de_champ_public) { [header_1, champ_explication, header_1_2, champ_communes, header_1_2_3, champ_text, header_2, champ_textarea] }

    it 'closes every deeper section when a shallower one starts' do
      expect(tree.roots_public).to eq([tdc(99), tdc(299)])
      expect(tree.children_of(tdc(99))).to eq([tdc(599), tdc(199)])
      expect(tree.children_of(tdc(199))).to eq([tdc(699), tdc(799)])
      expect(tree.children_of(tdc(799))).to eq([tdc(399)])
      expect(tree.children_of(tdc(299))).to eq([tdc(499)])
    end
  end

  describe 'with a repetition' do
    let(:types_de_champ_public) do
      [
        header_1,
        { type: :repetition, stable_id: 899, children: [{ stable_id: 999 }, { type: :integer_number, stable_id: 1099 }] },
      ]
    end

    it 'indexes the repetition content under the repetition' do
      expect(tree.roots_public).to eq([tdc(99)])
      expect(tree.children_of(tdc(99))).to eq([tdc(899)])
      expect(tree.children_of(tdc(899))).to eq([tdc(999), tdc(1099)])
      expect(tree.ancestors_of(tdc(999))).to eq([tdc(99), tdc(899)])
    end
  end

  describe 'with a legacy type de champ without a type' do
    let(:types_de_champ_public) { [champ_text, champ_textarea] }

    before do
      draft.revision_types_de_champ
        .find { it.type_de_champ.stable_id == 399 }
        .type_de_champ.update_column(:type_champ, nil)
    end

    it 'skips it' do
      expect(tree.roots_public).to eq([tdc(499)])
      expect(tree.type_de_champ(399)).to be_nil
    end
  end

  describe 'with private types de champ' do
    let(:types_de_champ_public) { [champ_text] }
    let(:procedure) { create(:procedure, types_de_champ_public:, types_de_champ_private: [{ type: :textarea, stable_id: 1199 }]) }

    it 'indexes both scopes' do
      expect(tree.roots_public).to eq([tdc(399)])
      expect(tree.roots_private).to eq([tdc(1199)])
      expect(tree.type_de_champ('399')).to eq(tdc(399))
      expect(tree.type_de_champ(0)).to be_nil
    end
  end
end
