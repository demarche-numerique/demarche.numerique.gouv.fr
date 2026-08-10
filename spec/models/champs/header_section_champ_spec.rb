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
      let(:champ) { dossier.root_public_champs.find { it.libelle == 's1' } }

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
      let(:repetition) { dossier.root_public_champs.find { it.libelle == 'rep' } }
      let(:champ) { repetition.rows.first.champs.find { it.libelle == 'rs1' } }

      it 'returns the projected champs of the same row' do
        expect(champ.children.map(&:libelle)).to eq(['rt1'])
        expect(champ.children).to all(have_attributes(row_id: champ.row_id))
      end
    end
  end

  describe '#flat_children' do
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:procedure) do
      create(:procedure, types_de_champ_public: [
        { type: :header_section, level: 1, libelle: 's1' },
        { type: :text, libelle: 't1' },
        { type: :header_section, level: 2, libelle: 's1.1' },
        { type: :repetition, libelle: 'rep', children: [{ type: :text, libelle: 'rt1' }] },
      ])
    end
    let(:champ) { dossier.root_public_champs.find { it.libelle == 's1' } }

    it 'expands nested repetitions into their rows, each with its own row_id' do
      repetition = dossier.root_public_champs.find { it.libelle == 'rep' }

      expect(champ.flat_children.map(&:libelle)).to eq(['t1', 's1.1', 'rep', 'rt1', 'rt1'])
      expect(champ.flat_children.filter { it.libelle == 'rt1' }.map(&:row_id)).to eq(repetition.row_ids)
      expect(champ.flat_children.filter { it.libelle != 'rt1' }).to all(have_attributes(row_id: nil))
    end
  end
end
