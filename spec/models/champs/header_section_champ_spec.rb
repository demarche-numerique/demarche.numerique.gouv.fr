# frozen_string_literal: true

describe Champs::HeaderSectionChamp do
  describe '#children' do
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }

    context 'at the root of the form' do
      let(:procedure) do
        create(:procedure, types_de_champ_public: [
          { type: :header_section, level: 1, libelle: 's1' },
          { type: :text, libelle: 't1' },
          { type: :header_section, level: 2, libelle: 's1.1' },
          { type: :text, libelle: 't1.1' },
        ])
      end
      let(:champ) { dossier.root_champs_public.find { it.libelle == 's1' } }

      it 'returns the projected champs of its direct children' do
        expect(champ.children.map(&:libelle)).to eq(['t1', 's1.1'])
        expect(champ.children).to all(have_attributes(row_id: nil))
      end
    end

    context 'inside a repetition' do
      let(:procedure) do
        create(:procedure, types_de_champ_public: [
          {
            type: :repetition, libelle: 'rep', children: [
              { type: :header_section, level: 1, libelle: 'rs1' },
              { type: :text, libelle: 'rt1' },
            ],
          },
        ])
      end
      let(:repetition) { dossier.root_champs_public.find { it.libelle == 'rep' } }
      let(:champ) { repetition.rows.first.champs.find { it.libelle == 'rs1' } }

      it 'returns the projected champs of the same row' do
        expect(champ.children.map(&:libelle)).to eq(['rt1'])
        expect(champ.children).to all(have_attributes(row_id: champ.row_id))
      end
    end
  end
end
