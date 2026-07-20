# frozen_string_literal: true

describe TypesDeChamp::RepetitionTypeDeChamp do
  describe '#children' do
    let(:revision) { procedure.draft_revision }
    let(:repetition) { revision.root_types_de_champ_public.find(&:repetition?) }

    subject(:children_libelles) { repetition.children(revision).map(&:libelle) }

    context 'without sections' do
      let(:procedure) do
        create(:procedure, types_de_champ_public: [
          {
            type: :repetition, libelle: 'rep', children: [
              { type: :text, libelle: 't1' },
              { type: :integer_number, libelle: 'n1' },
            ],
          },
        ])
      end

      it { is_expected.to eq(['t1', 'n1']) }
    end

    context 'with nested sections' do
      let(:procedure) do
        create(:procedure, types_de_champ_public: [
          {
            type: :repetition, libelle: 'rep', children: [
              { type: :text, libelle: 't1' },
              { type: :header_section, level: 1, libelle: 's1' },
              { type: :text, libelle: 't1.1' },
              { type: :header_section, level: 2, libelle: 's1.1' },
              { type: :text, libelle: 't1.1.1' },
            ],
          },
        ])
      end

      it 'returns only direct children' do
        expect(children_libelles).to eq(['t1', 's1'])
      end
    end
  end
end
