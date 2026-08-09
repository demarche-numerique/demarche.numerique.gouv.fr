# frozen_string_literal: true

describe TypesDeChamp::HeaderSectionTypeDeChamp do
  describe '#children' do
    let(:revision) { procedure.draft_revision }

    def children_libelles(libelle)
      tdc = revision.types_de_champ.find { it.libelle == libelle }
      tdc.children.map(&:libelle)
    end

    context 'with nested sections' do
      let(:procedure) do
        create(:procedure, types_de_champ_public: [
          { type: :header_section, level: 1, libelle: 's1' },
          { type: :text, libelle: 't1' },
          { type: :header_section, level: 2, libelle: 's1.1' },
          { type: :text, libelle: 't1.1' },
          { type: :header_section, level: 1, libelle: 's2' },
          { type: :text, libelle: 't2' },
        ])
      end

      it 'returns only direct children' do
        expect(children_libelles('s1')).to eq(['t1', 's1.1'])
        expect(children_libelles('s1.1')).to eq(['t1.1'])
        expect(children_libelles('s2')).to eq(['t2'])
      end
    end

    context 'with a level gap' do
      let(:procedure) do
        create(:procedure, types_de_champ_public: [
          { type: :header_section, level: 1, libelle: 's1' },
          { type: :header_section, level: 3, libelle: 's1.1' },
          { type: :text, libelle: 't1.1' },
        ])
      end

      it 'attaches the deeper section to the closest ancestor' do
        expect(children_libelles('s1')).to eq(['s1.1'])
        expect(children_libelles('s1.1')).to eq(['t1.1'])
      end
    end

    context 'with a level gap after a previous sibling subtree' do
      let(:procedure) do
        create(:procedure, types_de_champ_public: [
          { type: :header_section, level: 1, libelle: 's1' },
          { type: :header_section, level: 2, libelle: 's1.1' },
          { type: :header_section, level: 1, libelle: 's2' },
          { type: :header_section, level: 3, libelle: 's2.1' },
        ])
      end

      it 'attaches the deeper section to the current section, not the previous sibling subtree' do
        expect(children_libelles('s2')).to eq(['s2.1'])
        expect(children_libelles('s1.1')).to eq([])
      end
    end

    context 'with an empty section' do
      let(:procedure) do
        create(:procedure, types_de_champ_public: [
          { type: :header_section, level: 1, libelle: 's1' },
          { type: :header_section, level: 1, libelle: 's2' },
        ])
      end

      it { expect(children_libelles('s1')).to eq([]) }
    end

    context 'inside a repetition' do
      let(:procedure) do
        create(:procedure, types_de_champ_public: [
          {
            type: :repetition, libelle: 'rep', children: [
              { type: :header_section, level: 1, libelle: 'rs1' },
              { type: :text, libelle: 'rt1' },
              { type: :header_section, level: 1, libelle: 'rs2' },
              { type: :text, libelle: 'rt2' },
            ],
          },
        ])
      end

      it 'only includes siblings within the repetition' do
        expect(children_libelles('rs1')).to eq(['rt1'])
        expect(children_libelles('rs2')).to eq(['rt2'])
      end
    end

    context 'with a private section' do
      let(:procedure) do
        create(:procedure,
          types_de_champ_public: [{ type: :text, libelle: 'public' }],
          types_de_champ_private: [
            { type: :header_section, level: 1, libelle: 'ps1' },
            { type: :text, libelle: 'pt1' },
          ])
      end

      it { expect(children_libelles('ps1')).to eq(['pt1']) }
    end
  end

  describe '#flat_children' do
    let(:revision) { procedure.draft_revision }

    def flat_children_libelles(libelle)
      tdc = revision.types_de_champ.find { it.libelle == libelle }
      tdc.flat_children.map(&:libelle)
    end

    let(:procedure) do
      create(:procedure, types_de_champ_public: [
        { type: :header_section, level: 1, libelle: 's1' },
        { type: :text, libelle: 't1' },
        { type: :header_section, level: 2, libelle: 's1.1' },
        { type: :text, libelle: 't1.1' },
        { type: :repetition, libelle: 'rep', children: [{ type: :text, libelle: 'rt1' }] },
        { type: :header_section, level: 1, libelle: 's2' },
        { type: :text, libelle: 't2' },
      ])
    end

    it 'returns every type de champ below, in document order, including nested section headers' do
      expect(flat_children_libelles('s1')).to eq(['t1', 's1.1', 't1.1', 'rep', 'rt1'])
      expect(flat_children_libelles('s1.1')).to eq(['t1.1', 'rep', 'rt1'])
      expect(flat_children_libelles('s2')).to eq(['t2'])
    end

    it 'includes a nested repetition and its row content' do
      expect(flat_children_libelles('s1')).to include('rt1')
      expect(flat_children_libelles('rep')).to eq(['rt1'])
    end
  end
end
