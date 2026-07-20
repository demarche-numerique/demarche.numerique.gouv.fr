# frozen_string_literal: true

describe TypesDeChamp::TypeDeChampBase do
  describe '#ancestors, #parent, #section and #repetition' do
    let(:procedure) do
      create(:procedure,
        types_de_champ_public: [
          { type: :text, libelle: 't0' },
          { type: :header_section, level: 1, libelle: 's1' },
          { type: :header_section, level: 2, libelle: 's1.1' },
          {
            type: :repetition, libelle: 'rep', children: [
              { type: :header_section, level: 1, libelle: 'rs1' },
              { type: :text, libelle: 'rt1' },
            ],
          },
        ],
        types_de_champ_private: [
          { type: :header_section, level: 1, libelle: 'ps1' },
          { type: :text, libelle: 'pt1' },
        ])
    end
    let(:revision) { procedure.draft_revision }

    def tdc(libelle) = revision.types_de_champ.find { it.libelle == libelle }

    it 'returns sections and repetitions above, outermost first' do
      expect(tdc('t0').ancestors(revision)).to eq([])
      expect(tdc('s1').ancestors(revision)).to eq([])
      expect(tdc('s1.1').ancestors(revision).map(&:libelle)).to eq(['s1'])
      expect(tdc('rep').ancestors(revision).map(&:libelle)).to eq(['s1', 's1.1'])
      expect(tdc('rs1').ancestors(revision).map(&:libelle)).to eq(['s1', 's1.1', 'rep'])
      expect(tdc('rt1').ancestors(revision).map(&:libelle)).to eq(['s1', 's1.1', 'rep', 'rs1'])
      expect(tdc('pt1').ancestors(revision).map(&:libelle)).to eq(['ps1'])
    end

    it 'exposes parent, section and repetition' do
      expect(tdc('t0').parent(revision)).to be_nil
      expect(tdc('t0').section(revision)).to be_nil
      expect(tdc('t0').repetition(revision)).to be_nil

      expect(tdc('rt1').parent(revision).libelle).to eq('rs1')
      expect(tdc('rt1').section(revision).libelle).to eq('rs1')
      expect(tdc('rt1').repetition(revision).libelle).to eq('rep')
      expect(tdc('rs1').section(revision).libelle).to eq('s1.1')
    end

    it 'exposes in_repetition? and in_section?' do
      expect(tdc('t0').in_repetition?(revision)).to be(false)
      expect(tdc('t0').in_section?(revision)).to be(false)

      expect(tdc('s1.1').in_repetition?(revision)).to be(false)
      expect(tdc('s1.1').in_section?(revision)).to be(true)

      expect(tdc('rep').in_repetition?(revision)).to be(false)
      expect(tdc('rep').in_section?(revision)).to be(true)

      expect(tdc('rt1').in_repetition?(revision)).to be(true)
      expect(tdc('rt1').in_section?(revision)).to be(true)
    end

    it 'exposes level as the nesting depth of a header section' do
      expect(tdc('s1').level(revision)).to eq(1)
      expect(tdc('s1.1').level(revision)).to eq(2)
      expect(tdc('rs1').level(revision)).to eq(3)
      expect(tdc('ps1').level(revision)).to eq(1)
    end

    context 'when a header section level is skipped' do
      let(:procedure) do
        create(:procedure, types_de_champ_public: [
          { type: :header_section, level: 1, libelle: 's1' },
          { type: :header_section, level: 3, libelle: 's3' },
        ])
      end

      it 'collapses the gap' do
        expect(tdc('s3').ancestors(revision).map(&:libelle)).to eq(['s1'])
        expect(tdc('s3').level(revision)).to eq(2)
      end
    end
  end
end
